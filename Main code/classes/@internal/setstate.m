function setstate(mh, name, count)
if ~isfield(mh.trial.state,name)
    mh.trial.state.(name).count=0;
end
if nargin < 3
    count=mh.trial.state.(name).count+1;
    mh.trial.state.(name).count=count;
end

% Psychtoolbox time (GetSecs), like every live time in a trial. When the trial
% is saved, trialRecord turns these into requested_ms (ms since the trial start).
mh.trial.state.(name).time(count)=GetSecs;

if ~strcmp(mh.activestatename,name)
    mh.activestatetime = mh.trial.state.(name).time(end);
    mh.activestatename = name;
end
% Event marker: one unique integer code per state name (see stateEventCode).
% A single parallel-port digout (output 5) creates a NIP-timestamped digital
% marker (digin reason bit 32) that Trellis records, so this state's onset is
% timestamped in the neural data; the code<->name table is saved in trial.data.
xippmex('digout', 5, stateEventCode(name));

% Publish this onset (name + NIP tick) to the live-monitor slot so TrellisScope
% marks state onsets with NIP timestamps (same clock as its eye/spike data, to
% ~1 ms). The tick comes from nipTick, MHost2's cached NIP clock: calling
% xippmex('time') here on every state change crashed MATLAB twice (Sep/Oct 2026).
% A 32-deep ring means no onset is missed between the monitor's polls.
persistent soMap soRing soN
if isempty(soN), soN = 0; soRing = struct('name',{},'tick',{},'seq',{}); end
soN = soN + 1;
soRing(end+1) = struct('name',char(name),'tick',nipTick,'seq',soN); %#ok<AGROW>
if numel(soRing) > 32, soRing = soRing(end-31:end); end
try
    if isempty(soMap), soMap = sceneOpen(true, stateOnsetPath()); end
    sceneWrite(soMap, soN, struct('onsets', {soRing}));
catch
end

disp(name)
end