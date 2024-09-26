function out=trialint(mh,name)
if ~isnumeric(name)
    out=mh.trial.intervals.(name).duration;
else
    out=name;
end
end