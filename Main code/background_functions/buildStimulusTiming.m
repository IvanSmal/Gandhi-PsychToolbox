function [ev, fr, sync] = buildStimulusTiming(flips, ev, sync, photodiode, geom)
%BUILDSTIMULUSTIMING Match what the task asked to show with what the display showed.
%   [EV, FR, SYNC] = buildStimulusTiming(FLIPS, EV, SYNC, PHOTODIODE, GEOM)
%   builds a trial's stimulus timing tables. GraphicsHandler calls it when it
%   saves its flip log into the trial file (dumpdata).
%
%   Inputs
%     FLIPS       GraphicsHandler's log, one element per display flip of the
%                 trial: frame_id, vbl, onset (StimulusOnsetTime), missed,
%                 state, diode (square colour 0/1), toggle (the square changed
%                 colour on this flip: a state change), blank (the flip that
%                 cleared the display when the trial ended) and tags (the items
%                 the frame drew: tag, kind, rect in display pixels).
%     EV          MHost2's change log (mh.stimulusRequests): one row per item
%                 appearing or disappearing and per state change, with the ID
%                 and Psychtoolbox time of the frame that first asked for it.
%     SYNC        MHost2's clock data: nip_pairs ([GetSecs NIP-tick] read
%                 pairs, see nipTick), trace_start_tick (NIP tick of the first
%                 photodiode/eye sample), first_frame_id (this trial's), and
%                 trial_start_tick / trial_start_sample (passed through).
%     PHOTODIODE  data.photodiode, 1 kHz, starting at trace_start_tick.
%     GEOM        display: width, height, diode_rect, screenparams.
%
%   Outputs (structs of column arrays, readable outside MATLAB too)
%     EV    data.stimulus_events: per row tag, kind (target, tag or
%           photodiode), event (on, off or state), state, requested and
%           displayed (Psychtoolbox seconds), delay, flip, frame_id,
%           onset_tick and photon_tick (NIP 30 kHz ticks), x_deg, y_deg,
%           rect_px, missed. A change that never reached the screen (gone
%           again before the next flip) keeps displayed = NaN.
%     FR    data.stimulus_frames: one entry per item, one row per flip it was
%           on screen (same columns, plus state); the photodiode entry has one
%           row per colour change, i.e. per state change.
%     SYNC  data.clock_sync: the inputs plus fit (tick = ticks_per_s*GetSecs +
%           tick_at_0) and photodiode (the measured display delay).
%
%   Clocks. onset_tick is the flip's StimulusOnsetTime converted to the NIP
%   clock through the read pairs: the lowest (GetSecs - tick) per second is
%   the moment a sample was fresh, and a line through those is the offset.
%   photon_tick is when the item's light appeared: each colour change of
%   the photodiode square is found in the recorded photodiode trace, which
%   measures the delay from flip to light at the square; items get that delay,
%   shifted by the time the display takes to draw down from the square's
%   height to theirs. It is NaN when the trace shows no usable photodiode
%   signal (demo mode, or the photodiode not connected).

TPS = 30000;                                        % NIP ticks per second

if ~isstruct(ev) || ~isfield(ev, 'request_frame'), ev = emptyEvents(); end   % no change log saved
flips = trialFlips(flips, sync);
nF = numel(flips.frame_id);

% ---- clocks
[toTick, sync.fit] = fitClock(getf(sync, 'nip_pairs', zeros(0,2)), TPS);
onsetTick = round(toTick(flips.onset(:)));
good = ~flips.blank(:) & ~(flips.missed(:) > 0);
fd = median(diff(flips.vbl(good)));                 % frame duration (s)
if isempty(fd) || ~isfinite(fd) || fd < 0.004 || fd > 0.05, fd = 1/60; end
H = geom.height;
diodeY = mean(geom.diode_rect([2 4]));
scanTicks = @(y) (y ./ H) * fd * TPS;               % top of display -> row y

toggles = find(flips.toggle(:));
[edgeTick, sync.photodiode] = diodeEdges(photodiode, ...
    getf(sync, 'trace_start_tick', NaN), onsetTick(toggles), TPS);
lagT = sync.photodiode.lag_ms * TPS / 1000;         % flip -> light at the square
lightTick = @(t, y) round(t + lagT - scanTicks(diodeY) + scanTicks(y));
sync.frame_ms = fd * 1000;

% ---- which items each flip showed, and where
names = {};
for i = 1:nF
    t = flips.tags{i};
    for j = 1:numel(t)
        if ~any(strcmp(names, t(j).tag)), names{end+1} = t(j).tag; end %#ok<AGROW>
    end
end
nK = numel(names);
present = false(nF, nK);
rects = nan(nF, 4, nK);
kinds = repmat({'tag'}, 1, nK);
for i = 1:nF
    t = flips.tags{i};
    for j = 1:numel(t)
        k = find(strcmp(names, t(j).tag), 1);
        present(i, k) = true;
        kinds{k} = t(j).kind;
        if numel(t(j).rect) == 4, rects(i, :, k) = t(j).rect(:)'; end
    end
end

% ---- stimulus_frames
fr = struct();
% field names: valid MATLAB names; 'photodiode' is the square's, so a tag of
% that name becomes photodiode_1 (the entry's .name keeps the original)
keys = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName([{'photodiode'} names]));
pdKey = keys{1};
keys = keys(2:end);
for k = 1:nK
    r = find(present(:, k));
    R = rects(r, :, k);
    [x, y] = centreDeg(R, geom);
    fr.(keys{k}) = struct('name', names{k}, 'kind', kinds{k}, 'flip', r, ...
        'frame_id', col(flips.frame_id(r)), 'onset', col(flips.onset(r)), ...
        'onset_tick', onsetTick(r), 'photon_tick', lightTick(onsetTick(r), mean(R(:, [2 4]), 2)), ...
        'x_deg', x, 'y_deg', y, 'rect_px', R, 'missed', col(flips.missed(r)) > 0, ...
        'state', {col(flips.state(r))});                % {}: one struct, not one per row
end
D = repmat(geom.diode_rect(:)', numel(toggles), 1);
[x, y] = centreDeg(D, geom);
fr.(pdKey) = struct('name', 'photodiode', 'kind', 'photodiode', 'flip', toggles, ...
    'frame_id', col(flips.frame_id(toggles)), 'onset', col(flips.onset(toggles)), ...
    'onset_tick', onsetTick(toggles), 'photon_tick', round(edgeTick(:)), ...
    'x_deg', x, 'y_deg', y, 'rect_px', D, 'missed', col(flips.missed(toggles)) > 0, ...
    'state', {col(flips.state(toggles))}, 'color', col(flips.diode(toggles)));

% ---- what reached the screen: appear / disappear per item, colour changes
shown = struct('tag', {}, 'event', {}, 'state', {}, 'flip', {}, 'rect', {}, 'light', {});
for k = 1:nK
    p = present(:, k);
    for i = 1:nF
        before = i > 1 && p(i-1);
        if p(i) && ~before
            shown(end+1) = struct('tag', names{k}, 'event', 'on', 'state', '', 'flip', i, ...
                'rect', rects(i, :, k), 'light', NaN); %#ok<AGROW>
        elseif ~p(i) && before
            shown(end+1) = struct('tag', names{k}, 'event', 'off', 'state', '', 'flip', i, ...
                'rect', rects(i-1, :, k), 'light', NaN); %#ok<AGROW>
        end
    end
end
for j = 1:numel(toggles)
    shown(end+1) = struct('tag', 'photodiode', 'event', 'state', 'state', flips.state{toggles(j)}, ...
        'flip', toggles(j), 'rect', geom.diode_rect(:)', 'light', edgeTick(j)); %#ok<AGROW>
end

% ---- match each displayed change to the latest request for it
nE = numel(ev.tag);
reqFrame = col(ev.request_frame);
used = false(nE, 1);
extra = [];
for s = 1:numel(shown)
    i = shown(s).flip;
    c = find(~used & strcmp(ev.tag, shown(s).tag) & strcmp(ev.event, shown(s).event) & reqFrame <= flips.frame_id(i));
    if strcmp(shown(s).event, 'state')
        c = c(strcmp(ev.state(c), shown(s).state));
    end
    if isempty(c)
        extra(end+1) = s; %#ok<AGROW>   % shown with no request on record
        continue
    end
    [~, m] = max(reqFrame(c));
    e = c(m);
    used(e) = true;
    ev = fillRow(ev, e, shown(s), flips, onsetTick, lightTick, geom);
end
for s = extra                                        % keep them, requested = NaN
    e = numel(ev.tag) + 1;
    ev.tag{e, 1} = shown(s).tag;
    if strcmp(shown(s).tag, 'photodiode'), ev.kind{e, 1} = 'photodiode';
    else, ev.kind{e, 1} = kinds{strcmp(names, shown(s).tag)}; end
    ev.event{e, 1} = shown(s).event;
    ev.state{e, 1} = flips.state{shown(s).flip};
    ev.requested(e, 1) = NaN;
    ev = fillRow(ev, e, shown(s), flips, onsetTick, lightTick, geom);
end
ev = rmfield(ev, 'request_frame');
end

% =========================================================================
function ev = fillRow(ev, e, s, flips, onsetTick, lightTick, geom)
i = s.flip;
ev.displayed(e, 1) = flips.onset(i);
ev.delay(e, 1) = flips.onset(i) - ev.requested(e);
ev.flip(e, 1) = i;
ev.frame_id(e, 1) = flips.frame_id(i);
ev.onset_tick(e, 1) = onsetTick(i);
if strcmp(s.event, 'state')
    ev.photon_tick(e, 1) = round(s.light);       % measured at the square
else
    ev.photon_tick(e, 1) = lightTick(onsetTick(i), mean(s.rect([2 4])));
end
[ev.x_deg(e, 1), ev.y_deg(e, 1)] = centreDeg(s.rect, geom);
ev.rect_px(e, 1:4) = s.rect;
ev.missed(e, 1) = flips.missed(i) > 0;
if isempty(ev.state{e}), ev.state{e, 1} = flips.state{i}; end
end

function f = trialFlips(f, sync)
% This trial's flips only: a flip left over from the previous trial (the
% end-of-trial blank landing after that trial's dump) has an older frame ID.
first = getf(sync, 'first_frame_id', 0);
if isempty(f.frame_id), return, end
keep = f.frame_id(:) >= first;
for fn = fieldnames(f)'
    v = f.(fn{1});
    if numel(v) == numel(keep), f.(fn{1}) = v(keep); end
end
end

function [toTick, fit] = fitClock(P, TPS)
% Lower envelope of (GetSecs - tick/TPS): the read that found the freshest
% sample has the smallest delay. One minimum per second, then a line.
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
toTick = @(t) (t - o(t)) * TPS;
fit.ticks_per_s = TPS * (1 - p(1));
fit.tick_at_0 = -TPS * (p(2) - p(1) * g(1));
fit.read_delay_ms = median(r - o(g)) * 1000;        % typical age of the newest sample
end

function [edges, cal] = diodeEdges(x, startTick, pred, TPS)
% Colour changes of the photodiode square in the recorded trace, matched to
% the flips that made them (PRED, NIP ticks). Accepted only if the delays agree.
edges = nan(numel(pred), 1);
cal = struct('used', false, 'changes', numel(pred), 'found', 0, 'lag_ms', NaN, ...
    'lag_spread_ms', NaN, 'note', '');
x = double(x(:)');
if isempty(pred), cal.note = 'no colour changes this trial'; return, end
if isempty(x) || ~isfinite(startTick), cal.note = 'no photodiode trace'; return, end
s = sort(x(isfinite(x)));
if numel(s) < 10, cal.note = 'photodiode trace too short'; return, end
lo = s(max(1, round(0.02 * numel(s)))); hi = s(round(0.98 * numel(s)));
if ~(hi > lo), cal.note = 'flat photodiode signal'; return, end
thr = (lo + hi) / 2;
above = x > thr;
k = find(above(2:end) ~= above(1:end-1)) + 1;      % crossing between samples k-1 and k
dt = TPS / 1000;                                    % ticks per 1 kHz sample
tk = startTick + (k - 2) * dt + dt * (thr - x(k-1)) ./ (x(k) - x(k-1));
pred = pred(:);
lag = nan(numel(pred), 1);                          % first pass: first crossing 0-80 ms after
for j = 1:numel(pred)
    c = tk(tk >= pred(j) - 2 * dt & tk <= pred(j) + 80 * dt);
    if ~isempty(c), lag(j) = c(1) - pred(j); end
end
if nnz(isfinite(lag)) < max(2, numel(pred) / 2)
    cal.note = 'too few photodiode edges near the colour changes'; return
end
L = median(lag(isfinite(lag)));
tol = max(3 * dt, 3 * median(abs(lag(isfinite(lag)) - L)));
for j = 1:numel(pred)                               % second pass: nearest to the typical delay
    [dmin, m] = min(abs(tk - (pred(j) + L)));
    if ~isempty(dmin) && dmin <= tol, edges(j) = tk(m); end
end
ok = isfinite(edges);
d = edges(ok) - pred(ok);
spread = median(abs(d - median(d)));
cal.found = nnz(ok);
if cal.found < max(2, numel(pred) / 2) || spread > 3 * dt
    edges(:) = NaN;
    cal.note = 'photodiode edges do not line up with the colour changes';
    return
end
cal.used = true;
cal.lag_ms = median(d) / dt;
cal.lag_spread_ms = spread / dt;
end

function [x, y] = centreDeg(R, geom)
x = nan(size(R, 1), 1); y = x;
ok = all(isfinite(R), 2);
if ~any(ok), return, end
c = [mean(R(ok, [1 3]), 2), mean(R(ok, [2 4]), 2)];
dd = pix2deg(c, 'cart', getf(geom, 'screenparams', []));
if size(dd, 1) == nnz(ok)
    x(ok) = dd(:, 1); y(ok) = dd(:, 2);
end
end

function ev = emptyEvents()
c = cell(0, 1); z = zeros(0, 1);
ev = struct('tag', {c}, 'kind', {c}, 'event', {c}, 'state', {c}, 'requested', z, ...
    'request_frame', z, 'displayed', z, 'delay', z, 'flip', z, 'frame_id', z, ...
    'onset_tick', z, 'photon_tick', z, 'x_deg', z, 'y_deg', z, ...
    'rect_px', zeros(0, 4), 'missed', false(0, 1));
end

function v = col(v)
v = v(:);
end

function v = getf(s, f, default)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = default; end
end
