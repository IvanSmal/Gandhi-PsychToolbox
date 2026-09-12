function report = validateTasks(mh, taskDir, paramFile)
%VALIDATETASKS Check every task file (and the parameter file) before a run.
%   report = validateTasks(mh, taskDir, paramFile) does three checks:
%
%   1. SYNTAX. Every task .m in taskDir and the parameter file are parsed with
%      checkcode; anything MATLAB cannot parse (missing/extra end, unbalanced
%      brackets/parens, unterminated strings, ...) is reported. paramFile is
%      optional.
%   2. DECLARATIONS. Each task's gettarg / getint / gettexture / getmovie calls
%      are checked against what the parameter file declared into mh.
%   3. CUSTOM FUNCTIONS. Tasks that use a target whose custom path
%      (custompath_x/_y) names a function not on the MATLAB path are flagged --
%      i.e. custom functions the user has not imported yet.
%
%   Pure logic: shows no dialogs and changes nothing. The caller
%   (MHost2.validateLoadedTasks) decides how to report and offer a fix.
%
%   report.syntaxErrors: Nx2 cell {file, message} -- a file MATLAB cannot parse.
%   report.undeclared  : Nx3 cell {taskFile, kind, name} -- a fetched item the
%                        parameter file does not declare.
%   report.customTasks : cellstr of task files that need custom functions.
%   report.missingFns  : cellstr of the custom function names not on the path.

if nargin < 3, paramFile = ''; end
report.syntaxErrors = cell(0,2);
report.undeclared   = cell(0,3);
report.customTasks  = {};
report.missingFns   = {};

declared = struct( ...
    'gettarg',    {fieldnames(mh.targets)}, ...
    'getint',     {fieldnames(mh.intervals)}, ...
    'gettexture', {fieldnames(mh.textures)}, ...
    'getmovie',   {fieldnames(mh.movies)});
kindOf = struct('gettarg','target','getint','interval', ...
                'gettexture','texture','getmovie','movie');

% Which declared targets carry a custom path, and the function names each names.
targFns = struct();
for t = fieldnames(mh.targets)'
    tg = mh.targets.(t{1});
    fns = {};
    for s = {tg.custompath_x, tg.custompath_y}
        if ~isempty(s{1})
            hits = regexp(char(s{1}), '([A-Za-z]\w*)\s*\(', 'tokens');
            for k = 1:numel(hits), fns{end+1} = hits{k}{1}; end %#ok<AGROW>
        end
    end
    if ~isempty(fns), targFns.(t{1}) = reshape(unique(fns),1,[]); end
end

% ---- the parameter file's own syntax --------------------------------------
if ~isempty(paramFile) && exist(paramFile, 'file') == 2
    msg = syntaxError(paramFile);
    if ~isempty(msg)
        [~, pn, pe] = fileparts(paramFile);
        report.syntaxErrors(end+1,:) = {[pn pe], msg};
    end
end

files = dir(fullfile(taskDir, '*.m'));
for f = files'
    fpath = fullfile(f.folder, f.name);

    % ---- syntax first: a task that will not parse cannot run --------------
    msg = syntaxError(fpath);
    if ~isempty(msg)
        report.syntaxErrors(end+1,:) = {f.name, msg}; %#ok<AGROW>
    end

    src = fileread(fpath);
    src = regexprep(src, '%[^\n\r]*', '');          % drop line comments

    % Every gettarg/getint/gettexture/getmovie the task calls, by name.
    used = struct();
    for g = {'gettarg','getint','gettexture','getmovie'}
        names = regexp(src, ['\.' g{1} '\s*\(\s*[''"]([^''"]+)[''"]'], 'tokens');
        names = reshape(unique(cellfun(@(c) c{1}, names, 'UniformOutput', false)),1,[]);
        used.(g{1}) = names;
        for n = names
            if ~ismember(n{1}, declared.(g{1}))
                report.undeclared(end+1,:) = {f.name, kindOf.(g{1}), n{1}}; %#ok<AGROW>
            end
        end
    end

    % Does this task use a declared target that needs a not-yet-imported fn?
    miss = {};
    for n = used.gettarg
        if isfield(targFns, n{1})
            for fn = targFns.(n{1})
                if exist(fn{1}, 'file') ~= 2, miss{end+1} = fn{1}; end %#ok<AGROW>
            end
        end
    end
    if ~isempty(miss)
        report.customTasks{end+1} = f.name;         %#ok<AGROW>
        report.missingFns = [report.missingFns, miss];
    end
end

report.customTasks = unique(report.customTasks);
report.missingFns  = unique(report.missingFns);

% A parameter file that happens to sit in taskDir would be checked twice.
if size(report.syntaxErrors,1) > 1
    keys = strcat(report.syntaxErrors(:,1), '|', report.syntaxErrors(:,2));
    [~, ia] = unique(keys, 'stable');
    report.syntaxErrors = report.syntaxErrors(ia,:);
end
end

% ---------------------------------------------------------------------------
function msg = syntaxError(fpath)
%SYNTAXERROR '' if the file parses; otherwise the first parse error, "line N:
%   text". Only genuine syntax errors count -- undefined names (mh, deg2pix in
%   a parameter file) and style warnings are ignored.
msg = '';
try
    m = checkcode(fpath, '-id');
catch
    return   % checkcode itself failed; do not block on that
end
for k = 1:numel(m)
    isSyntax = ismember(m(k).id, {'SYNER','NOPAR','STRIN','ENDCT','MDEF','BADNE','MCEND'}) || ...
        ~isempty(regexpi(m(k).message, ...
            'parse error|invalid syntax|unterminated|missing a closing|might be missing', 'once'));
    if isSyntax
        msg = sprintf('line %d: %s', m(k).line(1), m(k).message);
        return
    end
end
end
