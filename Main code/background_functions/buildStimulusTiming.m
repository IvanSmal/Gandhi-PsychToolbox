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
%            in display pixels; res: a movie's resource id), movies (the
%            movie frames it drew: id, pts = presentation time in s) and
%            oneshots (the seeks / PlayMovie run before it: token, cmd, id,
%            value).
%     TR     the trial. Uses data.stimulus_events (MHost2's change log: one
%            row per item appearing or disappearing and per state change,
%            with the frame that first asked for it), data.clock_sync (clock
%            fit, trace_start_tick, first_frame_id), data.photodiode (1 kHz
%            from trace_start_tick) and start_tick.
%     GEOM   display: width, height, diode_rect, screenparams, movies (per
%            resource id: name, file, fps, frame_count, duration_s, width,
%            height, from OpenMovie).
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
%     Movies (kind 'movie'): per flip also movie_time_s (the shown frame's
%            presentation time within the movie), movie_frame (its number,
%            1 = first: the frame whose interval holds that time, from fps)
%            and new_frame (a different frame from the
%            flip before); events add seek and play rows (seek_to_s, rate),
%            displayed when the first new frame after the renderer ran them
%            reached the screen. A movie drawn without a destination rect is
%            centred at its own size, as Psychtoolbox draws it. A flip counts
%            as showing a movie only if the renderer drew a frame of it: until
%            the first frame is decoded the task's DrawTexture draws nothing.
%     The same numbers, through objectTiming, in trial.targets, trial.tags,
%     trial.movies and trial.state.
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
mvLogged = isfield(flips, 'movies') && numel(flips.movies) == nF;   % this renderer logs the movie frames it drew
if ~mvLogged, flips.movies = cell(1, nF); end
if ~isfield(flips, 'oneshots') || numel(flips.oneshots) ~= nF, flips.oneshots = cell(1, nF); end

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
resOf = zeros(1, nK);                               % a movie item's resource id
for i = 1:nF
    t = flips.tags{i};
    for j = 1:numel(t)
        k = find(strcmp(names, t(j).tag), 1);
        present(i, k) = true;
        kinds{k} = t(j).kind;
        if numel(t(j).rect) == 4, rects(i, :, k) = t(j).rect(:)'; end
        if isfield(t(j), 'res') && ~isempty(t(j).res) && t(j).res > 0, resOf(k) = t(j).res; end
    end
end

% ---- movies: which movie frame each flip showed
movies = getf(geom, 'movies', {});
mvPts = nan(nF, nK);                                % presentation time (s) of the shown frame
mvNew = false(nF, nK);                              % a different frame from the flip before
fpsOf = nan(1, nK);
for k = find(strcmp(kinds, 'movie') & resOf > 0)
    info = movieInfo(movies, resOf(k));
    fpsOf(k) = getf(info, 'fps', NaN);
    r = find(present(:, k))';
    for i = r
        m = flips.movies{i};
        j = [];
        if ~isempty(m), j = find([m.id] == resOf(k), 1, 'last'); end
        if ~isempty(j)
            mvPts(i, k) = m(j).pts;
        elseif mvLogged
            % the task drew it, but the renderer had no frame decoded yet and
            % drew nothing: not on screen at this flip
            present(i, k) = false;
        end
    end
    r = find(present(:, k))';
    p = mvPts(r, k);
    mvNew(r, k) = isfinite(p) & [true; p(2:end) ~= p(1:end-1)];
    % no destination rect: Psychtoolbox centres the movie at its own size
    w = getf(info, 'width', NaN); h = getf(info, 'height', NaN);
    for i = r
        if all(isnan(rects(i, :, k))) && isfinite(w) && isfinite(h)
            rects(i, :, k) = [(geom.width - w) / 2, (geom.height - h) / 2, (geom.width + w) / 2, (geom.height + h) / 2];
        end
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
    if strcmp(kinds{k}, 'movie')
        fr.(keys{k}).movie_time_s = mvPts(r, k);
        fr.(keys{k}).movie_frame = frameNo(mvPts(r, k), fpsOf(k));
        fr.(keys{k}).new_frame = mvNew(r, k);
    end
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
shown = struct('tag', {}, 'event', {}, 'state', {}, 'flip', {}, 'rect', {}, 'light', {}, 'pts', {}, 'fps', {});
for k = 1:nK
    p = present(:, k);
    for i = 1:nF
        before = i > 1 && p(i-1);
        if p(i) && ~before
            shown(end+1) = struct('tag', names{k}, 'event', 'on', 'state', '', 'flip', i, ...
                'rect', rects(i, :, k), 'light', NaN, 'pts', mvPts(i, k), 'fps', fpsOf(k)); %#ok<AGROW>
        elseif ~p(i) && before
            % off: the movie frame on screen until then
            shown(end+1) = struct('tag', names{k}, 'event', 'off', 'state', '', 'flip', i, ...
                'rect', rects(i-1, :, k), 'light', NaN, 'pts', mvPts(i-1, k), 'fps', fpsOf(k)); %#ok<AGROW>
        end
    end
end
for j = 1:numel(toggles)
    shown(end+1) = struct('tag', 'photodiode', 'event', 'state', 'state', flips.state{toggles(j)}, ...
        'flip', toggles(j), 'rect', geom.diode_rect(:)', 'light', edgeTick(j), 'pts', NaN, 'fps', NaN); %#ok<AGROW>
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
    if isfield(ev, 'seek_to_s'), ev.seek_to_s(e, 1) = NaN; ev.rate(e, 1) = NaN; end
    if isfield(ev, 'request_token'), ev.request_token(e, 1) = NaN; end
    ev = fillRow(ev, e, shown(s), flips, T, geom);
end
% ---- movie seeks and PlayMovie: the renderer ran each before a flip (logged
% by token); displayed = the first new frame of that movie from then on
if isfield(ev, 'request_token')
    for e = find(ismember(ev.event, {'seek', 'play'}))'
        ia = []; mid = [];
        for i = 1:nF
            o = flips.oneshots{i};
            if ~isempty(o) && any([o.token] == ev.request_token(e))
                ia = i; mid = o(find([o.token] == ev.request_token(e), 1)).id; break
            end
        end
        if isempty(ia), continue, end                % not run during this trial's flips
        k = find(resOf == mid, 1);
        if isempty(k), continue, end                 % the movie was not drawn this trial
        i = find(present(ia:end, k) & mvNew(ia:end, k), 1) + ia - 1;
        if isempty(i), continue, end
        ev = fillRow(ev, e, struct('tag', ev.tag{e}, 'event', ev.event{e}, 'state', '', 'flip', i, ...
            'rect', rects(i, :, k), 'light', NaN, 'pts', mvPts(i, k), 'fps', fpsOf(k)), flips, T, geom);
    end
end
D.stimulus_events = rmfield(ev, intersect(fieldnames(ev), {'request_frame', 'request_secs', 'request_token'}));
D.stimulus_frames = fr;
D.clock_sync = sync;
tr.data = D;
% the settings of each movie this trial drew or controlled, for trial.movies
% (objectTiming adds its events and frames)
mvNames = unique([names(strcmp(kinds, 'movie')), ev.tag(strcmp(ev.kind, 'movie'))'], 'stable');
if ~isfield(tr, 'movies') || ~isstruct(tr.movies), tr.movies = struct(); end
for n = mvNames
    info = struct();
    for i = 1:numel(movies)
        if isstruct(movies{i}) && strcmp(getf(movies{i}, 'name', ''), n{1}), info = movies{i}; end
    end
    tr.movies.(matlab.lang.makeValidName(n{1})) = movieSettings(info, n{1});
end
tr = objectTiming(tr);
end

% =========================================================================
function ev = fillRow(ev, e, s, flips, T, geom)
i = s.flip;
if isfield(ev, 'movie_time_s')
    ev.movie_time_s(e, 1) = s.pts;
    ev.movie_frame(e, 1) = frameNo(s.pts, s.fps);
end
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
    'x_deg', z, 'y_deg', z, 'rect_px', zeros(0, 4), 'missed', false(0, 1), ...
    'movie_time_s', z, 'movie_frame', z, 'seek_to_s', z, 'rate', z, ...
    'request_frame', z, 'request_token', z);
end

function n = frameNo(pts, fps)
% movie frame number, 1 = the first: the frame whose interval holds the
% presentation time. Usually that time is the frame's start, (n-1)/fps; right
% after a seek the decoder may report the seek target instead, somewhere inside
% the frame (rig2: 2.45 s for frame 74, which starts at 2.433 s), so round()
% would give the next frame. The tolerance (1e-4 of a frame) keeps a start
% time that came out a few ns early from falling into the frame before.
if isfinite(fps) && fps > 0, n = floor(pts .* fps + 1e-4) + 1; else, n = nan(size(pts)); end
end

function info = movieInfo(movies, id)
% the renderer's settings for movie resource ID, [] if unknown
info = [];
if id >= 1 && id <= numel(movies) && isstruct(movies{id}), info = movies{id}; end
end

function m = movieSettings(info, name)
% trial.movies.<name>: the movie's file and settings from OpenMovie
m = struct('name', name, 'file', getf(info, 'file', ''), 'fps', getf(info, 'fps', NaN), ...
    'frame_count', getf(info, 'frame_count', NaN), 'duration_s', getf(info, 'duration_s', NaN), ...
    'width', getf(info, 'width', NaN), 'height', getf(info, 'height', NaN));
end

function v = col(v)
v = v(:);
end

function v = getf(s, f, default)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = default; end
end
