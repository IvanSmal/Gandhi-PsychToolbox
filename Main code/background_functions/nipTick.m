function tick = nipTick(ts, nSamples)
%NIPTICK Cached NIP clock (30 kHz ticks), so hot paths need not call xippmex('time').
%   nipTick(ts, n)  record TS as returned by xippmex('cont', chans, n, '1ksps'):
%                   the tick of the FIRST of n samples, which are 30 ticks apart.
%                   Also logs a [GetSecs, tick of the newest sample] pair; those
%                   pairs put display times on the NIP clock (data.clock_sync,
%                   see buildStimulusTiming).
%   t = nipTick     current tick = last recorded sample + time elapsed since.
%   nipTick('reset')         start a fresh pair log (each trial, in starttrial).
%   P = nipTick('pairs')     the pairs logged since, n x 2: [GetSecs tick].
%
%   xippmex('time') walks every stream's buffer inside xippmex and crashed MATLAB
%   on 2026-09-25 and 2026-10-19, so setstate reads this cache instead. MHost2's
%   trial loop records on every pass; until the first record in a MATLAB session
%   this falls back to xippmex('time').
persistent lastTick lastTic pairs nPairs
if isempty(nPairs), nPairs = 0; pairs = zeros(20000, 2); end
if nargin
    if ischar(ts) || isstring(ts)
        if strcmpi(ts, 'pairs')
            tick = pairs(1:nPairs, :);
        else
            nPairs = 0;                     % 'reset'
        end
        return
    end
    if isempty(ts), return; end             % failed read: keep the previous record
    lastTick = double(ts(1)) + (nSamples-1)*30;
    lastTic = tic;                          % own timer: leaves the loop's tic/toc alone
    if nPairs == size(pairs, 1), pairs(2*end, 2) = 0; end   % grow (a trial longer than ~20 s)
    nPairs = nPairs + 1;
    pairs(nPairs, :) = [GetSecs, lastTick];
    return
end
if isempty(lastTick)
    tick = double(xippmex('time'));
else
    tick = lastTick + round(toc(lastTic)*30000);
end
end
