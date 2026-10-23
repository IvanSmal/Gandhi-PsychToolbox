function out=trialtarg(obj,name,arg,varargin)
%TRIALTARG Evaluate a property of a target already fetched for this trial.
%   try/catch rather than isfield for the same reason as TRIALINT: this is
%   on the trial loop's path.
try
    out=obj.trial.targets.(name).(arg)(obj,varargin{:});
catch err
    if isstruct(obj.trial.targets) && isfield(obj.trial.targets, name)
        rethrow(err)   % the target is there; the failure is in the property call
    end
    error('trialtarg:notfetched', ...
        ['target "%s" has not been fetched for this trial.\n' ...
         '    Fetched so far: %s\n' ...
         '    Call mh.gettarg(''%s'') in the trial setup block before ' ...
         'referring to it.'], ...
        name, declaredNames(obj.trial.targets), name);
end
end
