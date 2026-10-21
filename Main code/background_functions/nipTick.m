function tick = nipTick(ts, nSamples)
%NIPTICK Cached NIP clock (30 kHz ticks), so hot paths need not call xippmex('time').
%   nipTick(ts, n)  record TS as returned by xippmex('cont', chans, n, '1ksps'):
%                   the tick of the FIRST of n samples, which are 30 ticks apart.
%   t = nipTick     current tick = last recorded sample + time elapsed since.
%
%   xippmex('time') walks every stream's buffer inside xippmex and crashed MATLAB
%   on 2026-09-25 and 2026-10-19, so setstate reads this cache instead. MHost2's
%   trial loop records on every pass; until the first record in a MATLAB session
%   this falls back to xippmex('time').
persistent lastTick lastTic
if nargin
    if isempty(ts), return; end             % failed read: keep the previous record
    lastTick = double(ts(1)) + (nSamples-1)*30;
    lastTic = tic;                          % own timer: leaves the loop's tic/toc alone
    return
end
if isempty(lastTick)
    tick = double(xippmex('time'));
else
    tick = lastTick + round(toc(lastTic)*30000);
end
end
