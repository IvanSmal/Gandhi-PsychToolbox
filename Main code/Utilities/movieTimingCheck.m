function R = movieTimingCheck(t, name)
%MOVIETIMINGCHECK Check a trial's movie frames against the photodiode.
%   R = movieTimingCheck(TRIAL, NAME) for a trial recorded with the test
%   movie (makeMovieTimingTest) drawn so its corner square was under the
%   photodiode. The square is white on odd movie frames and black on even
%   ones, so the trace steps whenever the frame number's parity changes. For
%   every flip the saved data says showed a new movie frame of the other
%   parity, a step should follow at a steady delay; anything else means the
%   data and the screen disagree.
%   TRIAL is one element of e.trial (or a trial file's trial); NAME the
%   movie's name in trial.movies. R has the expected steps and the
%   photodiode crossings matched to them (both in ms since the trial start),
%   and the counts below, which are also printed:
%     matched     expected steps with a crossing 0-80 ms after the flip
%     missing     expected steps with none (the screen did not change)
%     extra       crossings no expected step explains (it changed unseen)
%     delay_ms    median and spread (median absolute deviation) of crossing
%                 minus displayed_ms over the matched steps: the display's
%                 own delay, the same for every frame if all is well
%     parity_ok   share of shown frames whose trace level (white / black)
%                 agrees with the frame number's parity
M = t.movies.(name);
F = M.frames;
d = t.data;
if isempty(F.frame_id)                              % asked for, but never on screen
    R = struct('expected_ms', zeros(0, 1), 'crossing_ms', zeros(0, 1), 'lag_ms', zeros(0, 1), ...
        'matched', 0, 'missing', 0, 'extra', 0, 'delay_ms', [NaN NaN], 'parity_ok', NaN);
    fprintf('%s: never shown in this trial\n', name);
    return
end
x = double(d.photodiode(:)'); tm = double(d.time_ms(:)');
% expected steps: a new frame whose number has the other parity. The movie's
% appearance and disappearance are left out: whether they make a step depends
% on what is behind the square.
par = mod(F.movie_frame(:), 2);
prev = [NaN; par(1:end-1)];
expStep = F.new_frame(:) & isfinite(par) & par ~= prev;
expStep(1) = false;
tExp = F.displayed_ms(expStep);
% the trace's crossings, placed between samples
s = sort(x(isfinite(x)));
lo = s(max(1, round(0.02 * numel(s)))); hi = s(round(0.98 * numel(s)));
thr = (lo + hi) / 2;
above = x > thr;
k = find(above(2:end) ~= above(1:end-1)) + 1;
tc = tm(k - 1) + (tm(k) - tm(k - 1)) .* (thr - x(k - 1)) ./ (x(k) - x(k - 1));
% match each expected step to the first unused crossing 0-80 ms after its flip
used = false(size(tc));
lag = nan(size(tExp));
for i = 1:numel(tExp)
    j = find(~used & tc >= tExp(i) - 2 & tc <= tExp(i) + 80, 1);
    if ~isempty(j), used(j) = true; lag(i) = tc(j) - tExp(i); end
end
during = tc > F.displayed_ms(1) + 80 & tc <= F.displayed_ms(end);   % within the movie, not its edges
R.expected_ms = tExp;
R.crossing_ms = tc(:);
R.lag_ms = lag;
R.matched = nnz(isfinite(lag));
R.missing = nnz(~isfinite(lag));
R.extra = nnz(~used & during);
L = median(lag, 'omitnan');
R.delay_ms = [L, median(abs(lag - L), 'omitnan')];
% parity: the trace level just after each shown frame should match it
lvl = interp1(tm, double(above), F.displayed_ms(:) + L + 2, 'nearest', NaN);
sh = isfinite(lvl) & isfinite(par);
agree = lvl(sh) == par(sh);
R.parity_ok = max(mean(agree), mean(~agree));       % whichever polarity the sensor has
fprintf(['%s: %d frames shown, %d expected steps: matched %d, missing %d, extra %d; ' ...
    'delay %.2f ms (spread %.2f); parity agrees on %.1f%% of frames\n'], name, numel(F.frame_id), ...
    numel(tExp), R.matched, R.missing, R.extra, R.delay_ms(1), R.delay_ms(2), 100 * R.parity_ok);
end
