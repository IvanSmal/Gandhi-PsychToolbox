function setstate(mh, name, count)
if ~isfield(mh.trial.state,name)
    mh.trial.state.(name).count=0;
end
if nargin < 3
    count=mh.trial.state.(name).count+1;
    mh.trial.state.(name).count=count;
end

mh.trial.state.(name).time(count)=getsecs;

if ~strcmp(mh.activestatename,name)
    mh.activestatetime = mh.trial.state.(name).time(end);
    mh.activestatename = name;
end
% Event marker: one unique integer code per state name (see stateEventCode).
% A single parallel-port digout (output 5) creates a NIP-timestamped digital
% marker (digin reason bit 32) that Trellis records, so this state's onset is
% timestamped in the neural data; the code<->name table is saved in trial.data.
xippmex('digout', 5, stateEventCode(name));

disp(name)
end