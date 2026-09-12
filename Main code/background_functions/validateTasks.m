function report = validateTasks(mh, taskDir)
%VALIDATETASKS Check every task file against the loaded parameter file.
%   report = validateTasks(mh, taskDir) scans each .m task in taskDir for the
%   targets, intervals, textures and movies it fetches (gettarg / getint /
%   gettexture / getmovie) and checks each is declared by the parameter file
%   already loaded into mh. It also finds tasks that use a target whose custom
%   path (custompath_x/_y) names a function that is not currently on the
%   MATLAB path -- i.e. custom functions the user has not imported yet.
%
%   This is pure logic: it shows no dialogs and changes nothing. The caller
%   (MHost2.validateLoadedTasks) decides how to report and offer a fix.
%
%   report.undeclared : Nx3 cell {taskFile, kind, name} -- a fetched item the
%                       parameter file does not declare.
%   report.customTasks: cellstr of task files that need custom functions.
%   report.missingFns : cellstr of the custom function names not on the path.

report.undeclared  = cell(0,3);
report.customTasks = {};
report.missingFns  = {};

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

files = dir(fullfile(taskDir, '*.m'));
for f = files'
    src = fileread(fullfile(f.folder, f.name));
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
end
