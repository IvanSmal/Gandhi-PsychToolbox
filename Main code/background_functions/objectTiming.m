function s = objectTiming(s)
%OBJECTTIMING Give each target, tag and state its own copy of its timing.
%   S = objectTiming(S) copies each item's rows of the trial's flat tables
%   (data.stimulus_events, data.stimulus_frames) into trial.targets.<name>,
%   trial.movies.<name> for a movie, or trial.tags.<name> for an
%   mh.Screen(..., 'Tag', name) item:
%       events  one row per appearance (event 'on') and disappearance
%               ('off'): event, state, requested_ms, displayed_ms,
%               photon_ms, delay_ms, x_deg, y_deg, frame_id, missed
%       frames  one row per frame it was on screen: frame_id, requested_ms,
%               displayed_ms, photon_ms, x_deg, y_deg, rect_px, missed, state
%   A movie's events also have seek and play rows and the columns
%   movie_time_s, movie_frame, seek_to_s, rate; its frames movie_time_s,
%   movie_frame, new_frame (which movie frame each flip showed). Its settings
%   (file, fps, frame_count, duration_s, width, height) are kept from what
%   buildStimulusTiming put there.
%   And each state change's display times into trial.state.<name>
%   (displayed_ms, photon_ms, delay_ms, one row per entry). The copies are
%   the same numbers as the flat tables, so both always agree. trialRecord
%   and buildStimulusTiming call it; S is a trial in trialRecord's form.
D = s.data;
E = getf(D, 'stimulus_events', []);
F = getf(D, 'stimulus_frames', []);
if ~isstruct(E) || ~isfield(E, 'tag'), E = []; end
if ~isstruct(F), F = struct(); end

% ---- items, by name: targets get their own, the rest go to tags
names = {}; kindOf = {};
if ~isempty(E)
    k = ~strcmp(E.kind, 'photodiode');
    names = E.tag(k)'; kindOf = E.kind(k)';
end
fk = fieldnames(F);
fName = cell(1, numel(fk));
for i = 1:numel(fk)
    fName{i} = F.(fk{i}).name;
    if ~strcmp(F.(fk{i}).kind, 'photodiode'), names{end+1} = fName{i}; kindOf{end+1} = F.(fk{i}).kind; end %#ok<AGROW>
end
[names, u] = unique(names, 'stable'); kindOf = kindOf(u);
isMovie = strcmp(kindOf, 'movie');
isTarget = @(n) isstruct(s.targets) && isfield(s.targets, n) && isstruct(s.targets.(n));

if isstruct(s.targets)                              % a target never shown: empty tables
    tn = fieldnames(s.targets);
    for i = 1:numel(tn)
        if isstruct(s.targets.(tn{i}))
            s.targets.(tn{i}).events = eventRows(E, '', false);
            s.targets.(tn{i}).frames = frameRows([], false);
        end
    end
end
tagNames = names(~cellfun(isTarget, names) & ~isMovie);
tagKeys = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(tagNames));
s.tags = struct();
old = struct();
if isfield(s, 'movies') && isstruct(s.movies), old = s.movies; end
s.movies = struct();
for i = 1:numel(names)
    nm = names{i};
    j = find(strcmp(fName, nm), 1);
    if isempty(j), fr = frameRows([], isMovie(i)); else, fr = frameRows(F.(fk{j}), isMovie(i)); end
    ev = eventRows(E, nm, isMovie(i));
    if isMovie(i)
        key = matlab.lang.makeValidName(nm);
        if isfield(old, key)
            m = rmfield(old.(key), intersect(fieldnames(old.(key)), {'events', 'frames'}));
        else
            m = struct('name', nm, 'file', '', 'fps', NaN, 'frame_count', NaN, 'duration_s', NaN, 'width', NaN, 'height', NaN);
        end
        m.events = ev; m.frames = fr;
        s.movies.(key) = m;
    elseif isTarget(nm)
        s.targets.(nm).events = ev;
        s.targets.(nm).frames = fr;
    else
        s.tags.(tagKeys{strcmp(tagNames, nm)}) = struct('name', nm, 'events', ev, 'frames', fr);
    end
end

% ---- states: when each state change reached the screen
if isstruct(s.state) && ~isempty(E)
    for j = find(strcmp(E.event, 'state') & isfinite(E.entry))'
        nm = E.state{j}; k = E.entry(j);
        if ~isfield(s.state, nm) || k > numel(s.state.(nm).requested_ms), continue, end
        s.state.(nm).displayed_ms(k, 1) = E.displayed_ms(j);
        s.state.(nm).photon_ms(k, 1) = E.photon_ms(j);
        s.state.(nm).delay_ms(k, 1) = E.delay_ms(j);
    end
end
end

% =========================================================================
function ev = eventRows(E, name, isMovie)
if isempty(E)
    c = cell(0, 1); z = zeros(0, 1);
    ev = struct('event', {c}, 'state', {c}, 'requested_ms', z, 'displayed_ms', z, ...
        'photon_ms', z, 'delay_ms', z, 'x_deg', z, 'y_deg', z, 'frame_id', z, 'missed', false(0, 1));
    if isMovie, ev.movie_time_s = z; ev.movie_frame = z; ev.seek_to_s = z; ev.rate = z; end
    return
end
r = find(strcmp(E.tag, name) & ~strcmp(E.kind, 'photodiode'));
ev = struct('event', {E.event(r)}, 'state', {E.state(r)}, 'requested_ms', E.requested_ms(r), ...
    'displayed_ms', E.displayed_ms(r), 'photon_ms', E.photon_ms(r), 'delay_ms', E.delay_ms(r), ...
    'x_deg', E.x_deg(r), 'y_deg', E.y_deg(r), 'frame_id', E.frame_id(r), 'missed', E.missed(r));
if isMovie
    for f = {'movie_time_s', 'movie_frame', 'seek_to_s', 'rate'}
        if isfield(E, f{1}), ev.(f{1}) = E.(f{1})(r); else, ev.(f{1}) = nan(numel(r), 1); end
    end
end
end

function fr = frameRows(f, isMovie)
if isempty(f)
    z = zeros(0, 1);
    fr = struct('frame_id', z, 'requested_ms', z, 'displayed_ms', z, 'photon_ms', z, ...
        'x_deg', z, 'y_deg', z, 'rect_px', zeros(0, 4), 'missed', false(0, 1), 'state', {cell(0, 1)});
    if isMovie, fr.movie_time_s = z; fr.movie_frame = z; fr.new_frame = false(0, 1); end
    return
end
fr = struct('frame_id', f.frame_id, 'requested_ms', f.requested_ms, 'displayed_ms', f.displayed_ms, ...
    'photon_ms', f.photon_ms, 'x_deg', f.x_deg, 'y_deg', f.y_deg, 'rect_px', f.rect_px, ...
    'missed', f.missed, 'state', {f.state});
if isMovie
    for c = {'movie_time_s', 'movie_frame', 'new_frame'}
        if isfield(f, c{1}), fr.(c{1}) = f.(c{1}); else, fr.(c{1}) = nan(numel(f.frame_id), 1); end
    end
end
end

function v = getf(s, f, default)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = default; end
end
