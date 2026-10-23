function out=trialint(mh,name)
%TRIALINT Duration of an interval already fetched for the current trial.
%   Runs inside the trial loop, so the missing-name check is done with
%   try/catch rather than isfield: it costs nothing when the lookup
%   succeeds, and only builds a message on the failing path.
if ~isnumeric(name)
    try
        out=mh.trial.intervals.(name).duration;
    catch err
        if isstruct(mh.trial.intervals) && isfield(mh.trial.intervals, name)
            rethrow(err)   % the interval is there; the failure is elsewhere
        end
        error('trialint:notfetched', ...
            ['interval "%s" has not been fetched for this trial.\n' ...
             '    Fetched so far: %s\n' ...
             '    Call mh.getint(''%s'') in the trial setup block before ' ...
             'referring to it.'], ...
            name, declaredNames(mh.trial.intervals), name);
    end
else
    out=name;
end
end
