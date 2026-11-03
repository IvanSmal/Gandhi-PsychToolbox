function [ready, why] = graphicsReady(maxAgeS)
%GRAPHICSREADY Is GraphicsHandler ready to show the next trial?
%   ready = graphicsReady  reads the slot GraphicsHandler rewrites on every
%   loop while it is out of a trial (graphicsReadyPath). Ready: it is not
%   busy (reconnecting xippmex, see xippmexRefresh) and its newest loop is
%   under 0.25 s old, so it is running and has left the last trial.
%   graphicsReady(maxAgeS)  other age limit.
%   why: '' when ready, else 'busy', 'not responding' or 'not running' (never
%   published). One shared-memory read, tens of microseconds: MHost2 checks it
%   after every ITI and waits only while it is false.
persistent m
if nargin < 1 || isempty(maxAgeS), maxAgeS = 0.25; end
ready = false; why = 'not running';
try
    if isempty(m), m = sceneOpen(false, graphicsReadyPath()); end
    [s, ok] = sceneRead(m);
catch
    m = []; return
end
if ~ok || ~isfield(s, 'busy'), return, end
if s.busy
    why = 'busy';
elseif GetSecs - s.t > maxAgeS        % GetSecs is system-wide: s.t compares directly
    why = 'not responding';
else
    ready = true; why = '';
end
end
