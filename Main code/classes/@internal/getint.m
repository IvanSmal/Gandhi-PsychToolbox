function out=getint(mh,name)
%GETINT Draw this trial's value for an interval declared in the parameter file.
%   Errors by name if the loaded parameter file never declared it. That
%   mismatch -- the task expects one parameter file, the operator loaded
%   another -- otherwise surfaces only as "Unrecognized field name", which
%   says nothing about which file is at fault.
if ~isfield(mh.intervals, name)
    error('getint:undeclared', ...
        ['interval "%s" is not declared by the loaded parameter file.\n' ...
         '    Declared intervals: %s\n' ...
         '    Load the parameter file this task expects, or add ' ...
         'mh.addint(''%s'', duration) to the one you loaded.'], ...
        name, declaredNames(mh.intervals), name);
end
out=mh.intervals.(name).getint(1);
mh.trial.insert('intervals',out);
end
