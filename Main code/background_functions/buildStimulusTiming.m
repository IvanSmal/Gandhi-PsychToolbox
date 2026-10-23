function tr = buildStimulusTiming(flips, tr, geom)
%BUILDSTIMULUSTIMING Add what the display showed, and when, to a saved trial.
%   TR = buildStimulusTiming(FLIPS, TR, GEOM) fills the display side of a
%   trial's timing. GraphicsHandler calls it when it saves its flip log into
%   the trial file (dumpdata). TR is the trial in trialRecord's form (a
%   trial object is converted first).
%
%   Inputs
%     FLIPS  GraphicsHandler's log, one element per display flip of the
%            trial: frame_id, generated (GetSecs the frame was published),
%            vbl, onset (StimulusOnsetTime), missed, state, diode (square
%            colour 0/1), toggle (the square changed colour on this flip: a
%            state change), blank (the flip that cleared the display when the
%            trial ended) and tags (the items the frame drew: tag, kind, rect
%            in display pixels).
%     TR     the trial. Uses data.stimulus_events (MHost2's change log: one
%            row per item appearing or disappearing and per state change,
%            with the frame that first asked for it), data.clock_sync (clock
%            fit, trace_start_tick, first_frame_id), data.photodiode (1 kHz
%            from trace_start_tick) and start_tick.
%     GEOM   display: width, height, diode_rect, screenparams.
%
%   Fills (structs of column arrays, readable outside MATLAB too)
%     data.stimulus_events  per row displayed_ms, photon_ms, delay_ms,
%            displayed_tick, photon_tick, flip, frame_id, x_deg, y_deg,
%            rect_px, missed. A change that never reached the screen (gone
%            again before the next flip) keeps displayed_ms = NaN; one shown
%            with no request on record is added with requested_ms = NaN.
%     data.stimulus_frames  one entry per item, one row per flip it was on
%            screen: frame_id, requested_ms (when that frame was published),
%            displayed_ms, photon_ms, displayed_tick, photon_tick, x_deg,
%            y_deg, rect_px, missed, state. The photodiode entry has one row
%            per colour change, i.e. per state change, and its colour.
%     data.clock_sync  photodiode (the measured display delay), frame_ms.
%     The same numbers, through objectTiming, in trial.targets, trial.tags
%     and trial.state.
%
%   Times: *_ms are ms since the trial start (trial.start_tick), *_tick NIP
%   30 kHz ticks. displayed is the flip's StimulusOnsetTime put on the NIP
%   clock with the trial's clock fit. photon is when the item's light
%   appeared: each colour change of the photodiode square is found in the
%   recorded photodiode trace, which measures the delay from flip to light
%   at the square; items get that delay, shifted by the time the display
%   takes to draw down from the square's height to theirs. It is NaN for an
%   item wholly off the display, and for everything when the trace shows no
%   usable photodiode signal (demo mode, or the photodiode not connected).

TPS = 30000;                                        % NIP ticks per second
TPM = TPS / 1000;                                   % per ms

tr = trialRecord(tr, getf(geom, 'screenparams', []));   % unchanged if already saved by MHost2
D = tr.data;
ev = getf(D, 'stimulus_events', []);
sync = D.clock_sync;
if ~isstruct(ev) || ~isfield(ev, 'request_frame'), ev = emptyEvents(); end   % no change log saved
flips = trialFlips(flips, sync);
nF = numel(flips.frame_id);
if ~isfield(flips, 'generated') || numel(flips.generated) ~= nF, flips.generated = nan(1, nF); end

% ---- clocks
start = tr.start_tick;
toTick = nipClock(sync.fit);
tickMs = @(k) (k - start) / TPM;
onsetTick = round(toTick(flips.onset(:)));
if isfinite(sync.fit.ticks_per_s)
    secsMs = @(t) (toTick(t) - start) / TPM;
    dispMs = tickMs(onsetTick);
else                                                % no NIP reads (see trialRecord)
    secsMs = @(t) (t - sync.start_secs) * 1000;
    dispMs = secsMs(flips.onset(:));
end
good = ~flips.blank(:) & ~(flips.missed(:) > 0);
fd = median(diff(flips.vbl(good)));                 % frame duration (s)
if isempty(fd) || ~isfinite(fd) || fd < 0.004 || fd > 0.05, fd = 1/60; end
H = geom.height;
diodeY = mean(geom.diode_rect([2 4]));
scanTicks = @(y) (y ./ H) * fd * TPS;               % top of display -> row y

toggles = find(flips.toggle(:));
[edgeTick, sync.photodiode] = diodeEdges(getf(D, 'photodiode', []), ...
    getf(sync, 'trace_start_tick', NaN), onsetTick(toggles), TPS);
lagT = sync.photodiode.lag_ms * TPS / 1000;         % flip -> light at the square
lightTick = @(t, R) round(t + lagT - scanTicks(diodeY) + scanTicks(visibleY(R, geom)));
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
    ph = lightTick(onsetTick(r), R);
    fr.(keys{k}) = struct('name', names{k}, 'kind', kinds{k}, 'flip', r, ...
        'frame_id', col(flips.frame_id(r)), 'requested_ms', secsMs(col(flips.generated(r))), ...
        'displayed_ms', dispMs(r), 'photon_ms', tickMs(ph), ...
        'displayed_tick', onsetTick(r), 'photon_tick', ph, ...
        'x_deg', x, 'y_deg', y, 'rect_px', R, 'missed', col(flips.missed(r)) > 0, ...
        'state', {col(flips.state(r))});                % {}: one struct, not one per row
end
Dr = repmat(geom.diode_rect(:)', numel(toggles), 1);
[x, y] = centreDeg(Dr, geom);
ph = round(edgeTick(:));
fr.(pdKey) = struct('name', 'photodiode', 'kind', 'photodiode', 'flip', toggles, ...
    'frame_id', col(flips.frame_id(toggles)), 'requested_ms', secsMs(col(flips.generated(toggles))), ...
    'displayed_ms', dispMs(toggles), 'photon_ms', tickMs(ph), ...
    'displayed_tick', onsetTick(toggles), 'photon_tick', ph, ...
    'x_deg', x, 'y_deg', y, 'rect_px', Dr, 'missed', col(flips.missed(toggles)) > 0, ...
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
T = struct('onsetTick', onsetTick, 'dispMs', dispMs, 'tickMs', tickMs, 'lightTick', lightTick);
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
    ev = fillRow(ev, e, shown(s), flips, T, geom);
end
for s = extra                                        % keep them, requested_ms = NaN
    e = numel(ev.tag) + 1;
    ev.tag{e, 1} = shown(s).tag;
    if strcmp(shown(s).tag, 'photodiode'), ev.kind{e, 1} = 'photodiode';
    else, ev.kind{e, 1} = kinds{strcmp(names, shown(s).tag)}; end
    ev.event{e, 1} = shown(s).event;
    ev.state{e, 1} = flips.state{shown(s).flip};
    ev.entry(e, 1) = NaN;
    ev.requested_ms(e, 1) = NaN;
    ev = fillRow(ev, e, shown(s), flips, T, geom);
end
D.stimulus_events = rmfield(ev, intersect(fieldnames(ev), {'request_frame', 'request_secs'}));
D.stimulus_frames = fr;
D.clock_sync = sync;
tr.data = D;
tr = objectTiming(tr);
end

% =========================================================================
function ev = fillRow(ev, e, s, flips, T, geom)
i = s.flip;
ev.displayed_ms(e, 1) = T.dispMs(i);
ev.delay_ms(e, 1) = T.dispMs(i) - ev.requested_ms(e);
ev.displayed_tick(e, 1) = T.onsetTick(i);
if strcmp(s.event, 'state')
    ev.photon_tick(e, 1) = round(s.light);       % measured at the square
else
    ev.photon_tick(e, 1) = T.lightTick(T.onsetTick(i), s.rect);
end
ev.photon_ms(e, 1) = T.tickMs(ev.photon_tick(e));
ev.flip(e, 1) = i;
ev.frame_id(e, 1) = flips.frame_id(i);
[ev.x_deg(e, 1), ev.y_deg(e, 1)] = centreDeg(s.rect, geom);
ev.rect_px(e, 1:4) = s.rect;
ev.missed(e, 1) = flips.missed(i) > 0;
if isempty(ev.state{e}), ev.state{e, 1} = flips.state{i}; end
end

function y = visibleY(R, geom)
% Height (display px) of the middle of each box's part that is on the
% display; NaN if none of it is.
R = reshape(R, [], 4);
top = max(R(:, 2), 0);
bot = min(R(:, 4), geom.height);
on = top <= bot & R(:, 1) <= geom.width & R(:, 3) >= 0;
y = (top + bot) / 2;
y(~on) = NaN;
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
ev = struct('tag', {c}, 'kind', {c}, 'event', {c}, 'state', {c}, 'entry', z, ...
    'requested_ms', z, 'displayed_ms', z, 'photon_ms', z, 'delay_ms', z, ...
    'displayed_tick', z, 'photon_tick', z, 'flip', z, 'frame_id', z, ...
    'x_deg', z, 'y_deg', z, 'rect_px', zeros(0, 4), 'missed', false(0, 1), 'request_frame', z);
end

function v = col(v)
v = v(:);
end

function v = getf(s, f, default)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = default; end
end
