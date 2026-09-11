function ok = migrateRigConfig(inisDir, apply)
%MIGRATERIGCONFIG Split a legacy ScreenParams.ini into RigConfig.ini + state.
%
%   migrateRigConfig(inisDir)         dry run: reports, writes nothing
%   migrateRigConfig(inisDir, true)   performs the migration (backs up first)
%
%   Hand-written rig settings move to RigConfig.ini; machine-written values
%   stay in ScreenParams.ini (whose name the compiled RewardHandler depends on).
%
%   Lossless by construction: whole SECTIONS are routed to a destination and
%   every key in them is copied, so keys this script has never heard of still
%   survive. Any section not in CONFIG_SECTIONS stays in the state file.

if nargin < 2, apply = false; end
CONFIG_SECTIONS = {'screen info','for deg2pix','target window parameters'};

srcPath = fullfile(inisDir,'ScreenParams.ini');
src = IniConfig();
if ~src.ReadFile(srcPath)
    error('migrateRigConfig:noSource','Cannot read %s', srcPath);
end

% ---- snapshot every value before touching anything -----------------------
sections = cellfun(@(s) strip(s,'['), src.GetSections(), 'UniformOutput', false);
sections = cellfun(@(s) strip(s,']'), sections, 'UniformOutput', false);
snap = {};
for s = 1:numel(sections)
    keys = src.GetKeys(sections{s});
    for k = 1:numel(keys)
        snap(end+1,:) = {sections{s}, keys{k}, src.GetValues(sections{s},keys{k})}; %#ok<AGROW>
    end
end
fprintf('source %s: %d sections, %d keys\n', srcPath, numel(sections), size(snap,1));

% ---- build the two destinations from their documented templates ----------
cfg = loadTemplate(fullfile(inisDir,'RigConfig.example.ini'));
st  = loadTemplate(fullfile(inisDir,'ScreenParams.example.ini'));

nCfg = 0; nSt = 0;
for i = 1:size(snap,1)
    [sec, key, val] = deal(snap{i,1}, snap{i,2}, snap{i,3});
    if any(strcmpi(sec, CONFIG_SECTIONS))
        putValue(cfg, sec, key, val); nCfg = nCfg + 1;
    else
        putValue(st,  sec, key, val); nSt  = nSt  + 1;
    end
end
fprintf('routed: %d keys -> RigConfig.ini, %d keys -> ScreenParams.ini\n', nCfg, nSt);

% ---- verify every original value survives, in exactly one destination ----
bad = 0;
for i = 1:size(snap,1)
    [sec, key, val] = deal(snap{i,1}, snap{i,2}, snap{i,3});
    inCfg = cfg.IsKeys(sec,key); inSt = st.IsKeys(sec,key);
    if inCfg, got = cfg.GetValues(sec,key); else, got = st.GetValues(sec,key); end
    if ~(xor(inCfg,inSt) && isequaln(got,val))
        bad = bad + 1;
        fprintf('  LOSS [%s] %s : orig=%s got=%s (cfg=%d state=%d)\n', ...
            sec, key, mat2str(val), mat2str(got), inCfg, inSt);
    end
end
ok = (bad == 0);
fprintf('verification: %d/%d keys preserved exactly\n', size(snap,1)-bad, size(snap,1));
if ~ok, fprintf('ABORT: migration would lose data. Nothing written.\n'); return; end

if ~apply
    fprintf('DRY RUN - nothing written. Call with apply=true to perform it.\n'); return
end

ts = datestr(now,'yyyymmdd_HHMMSS');
copyfile(srcPath, [srcPath '.premigrate_' ts]);
cfg.WriteFile(fullfile(inisDir,'RigConfig.ini'));
st.WriteFile(srcPath);
fprintf('WROTE RigConfig.ini and rewrote ScreenParams.ini (backup: .premigrate_%s)\n', ts);
end

function ini = loadTemplate(p)
ini = IniConfig();
if isfile(p) && ini.ReadFile(p)
    return
end
ini = IniConfig(); ini.CreateIni();
end

function putValue(ini, sec, key, val)
if ~ini.IsSections(sec), ini.AddSections(sec); end
if ini.IsKeys(sec,key)
    ini.SetValues(sec,key,val);
else
    [~, nKeys] = ini.GetKeys(sec);
    ini.InsertKeys(sec, nKeys+1, key, val);
end
end
