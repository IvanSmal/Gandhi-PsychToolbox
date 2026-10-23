function [toTick, fit] = nipClock(in)
%NIPCLOCK Psychtoolbox time (GetSecs) -> NIP (Trellis) 30 kHz ticks.
%   [TOTICK, FIT] = nipClock(PAIRS) fits the [GetSecs tick] pairs nipTick
%   logged, one per NIP read this trial. TOTICK(t) converts GetSecs t to a
%   NIP tick; FIT is what is saved in data.clock_sync.fit:
%       tick = ticks_per_s * GetSecs + tick_at_0
%   pairs (how many), read_delay_ms (typical age of the newest sample when
%   it was read).
%   TOTICK = nipClock(FIT) rebuilds the conversion from a saved FIT, so
%   every process converts with the same line (trialRecord fits it,
%   buildStimulusTiming reuses it).
%
%   Each pair is taken when a read returns: GetSecs then, and the tick of
%   the newest sample it got. That sample is already a little old, by a
%   varying amount, so GetSecs - tick/30000 is the clock offset plus that
%   age. The smallest value in each second is a read that found a fresh
%   sample; a line through those minima is the offset, and its slope the
%   drift between the two clocks (fitted only over 5 s or more).
TPS = 30000;                                        % NIP ticks per second
if isstruct(in)
    fit = in;
    toTick = @(t) fit.ticks_per_s * t + fit.tick_at_0;
    return
end
P = in;
fit = struct('ticks_per_s', NaN, 'tick_at_0', NaN, 'pairs', size(P, 1), 'read_delay_ms', NaN);
toTick = @(t) nan(size(t));
if isempty(P), return, end
g = P(:, 1); r = g - P(:, 2) / TPS;
b = floor(g - g(1));
ub = unique(b);
gm = zeros(numel(ub), 1); rm = gm;
for j = 1:numel(ub)
    idx = find(b == ub(j));
    [rm(j), m] = min(r(idx));
    gm(j) = g(idx(m));
end
if numel(ub) >= 5                                   % drift only over 5 s or more
    p = polyfit(gm - g(1), rm, 1);
else
    p = [0 min(r)];
end
o = @(t) p(1) * (t - g(1)) + p(2);                  % GetSecs - true time
fit.ticks_per_s = TPS * (1 - p(1));
fit.tick_at_0 = -TPS * (p(2) - p(1) * g(1));
fit.read_delay_ms = median(r - o(g)) * 1000;
toTick = @(t) fit.ticks_per_s * t + fit.tick_at_0;
end
