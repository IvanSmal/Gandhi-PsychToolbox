function [refreshed, ok] = xippmexRefresh(maxAgeS, waitS)
%XIPPMEXREFRESH Reopen this process's xippmex connection once it is old.
%   [refreshed, ok] = xippmexRefresh  closes and reopens xippmex if this
%   process has held its connection for 30 min or more; otherwise does nothing
%   (a toc). Call it only where a ~0.1 s pause is harmless: between trials, or
%   idle. refreshed: a reconnect was done; ok: it connected again.
%   xippmexRefresh(maxAgeS, waitS)  other age limit; after reopening, wait up
%   to waitS seconds (default 0.5) for the 1 ksps analog stream to deliver
%   again, so the next trial's first eye reads are not empty (0 = no wait).
%   Environment variable GANDHI_XIPPMEX_REFRESH_S overrides the default age
%   (for testing).
%   due = xippmexRefresh('due')  true if the next call would reconnect; does
%   nothing else (GraphicsHandler marks itself busy first: graphicsReady).
%
%   Why: xippmex 1.7.2 held open for a whole session crashed MHost2 2 h 39 m
%   after start on 2026-10-26, -27 and -28 (segfault in xippmex's own network
%   thread, ModuleData::GetContDataBuffer). Closing after every trial, as main
%   did until 2026-10-21, had crashes of its own on reopen, so reconnect rarely:
%   30 min is far below the 2 h 39 m. A reconnect takes ~0.11 s on rig2.
%   The age counts from the first call in this MATLAB session.
persistent opened
refreshed = false; ok = true;
query = nargin >= 1 && ischar(maxAgeS) && strcmp(maxAgeS, 'due');
if query, maxAgeS = []; end
if nargin < 1 || isempty(maxAgeS)
    maxAgeS = 1800;
    e = str2double(getenv('GANDHI_XIPPMEX_REFRESH_S'));
    if isfinite(e) && e > 0, maxAgeS = e; end
end
if query, refreshed = ~isempty(opened) && toc(opened) >= maxAgeS; return, end
if nargin < 2 || isempty(waitS), waitS = 0.5; end
if isempty(opened), opened = tic; return, end
if toc(opened) < maxAgeS, return, end

refreshed = true;
try, xippmex('close'); catch, end
ok = false;
for attempt = 1:3
    try, ok = isequal(xippmex(), 1); catch, ok = false; end
    if ok, break, end
    pause(0.5);
end
opened = tic;                       % a failed reopen is retried after another maxAgeS
if ~ok || waitS <= 0, return, end
try
    an = xippmex('elec', 'analog');
    t = tic;
    while toc(t) < waitS
        r = xippmex('cont', an(1), 1, '1ksps');
        if ~isempty(r) && any(r(:) ~= 0), break, end
        pause(0.005);
    end
catch
end
end
