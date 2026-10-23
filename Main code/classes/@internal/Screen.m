function varargout = Screen(mh, varargin)
%SCREEN Psychtoolbox-style drawing, published through the shared scene slot.
%
%   Task files keep the Psychtoolbox syntax they have always used:
%       mh.Screen('FillOval', mh, colour, rect)
%       mh.Screen('sendtogr')
%
%   ANY Screen call is supported, not a fixed set of primitives. Arguments
%   are kept as real MATLAB values and serialised with the frame, so
%   DrawTexture, DrawDots, DrawLines, DrawText, FillPoly, procedural
%   gratings and anything Psychtoolbox adds later all pass through
%   unchanged. Nothing is eval'd on the far side.
%
%   This replaced a UDP command stream that serialised each call to MATLAB
%   source text: 1072 us per writeline, three per iteration, 77% of the
%   state-machine loop. The frame now costs ~5 us to encode and ~48 us to
%   publish.
%
%   Window argument, by convention (unchanged from before):
%       mh  or 'windowPtr'  -> draw on BOTH the display and the monitor
%       'monitoronly'       -> monitor (experimenter) window only
%       'displayonly'       -> display (animal) window only
%
%   Timestamping: end any drawing call with 'Tag', name to get when it was
%   asked for and when it reached the screen in data.stimulus_events and
%   data.stimulus_frames (see buildStimulusTiming):
%       mh.Screen('FillRect', 'windowPtr', [1 1 1], cueRect, 'Tag', 'cue')
%   The pair is removed before drawing. Targets drawn at the rectangle getpos
%   returned are tagged with their own name automatically. Only what is drawn
%   on the display counts, not 'monitoronly'.

if isempty(mh.sceneMap)
    mh.sceneMap = sceneOpen(true);
    mh.cmdList  = {};
end

cmd = varargin{1};
if ~(ischar(cmd) || isstring(cmd)), return; end

switch lower(string(cmd))
    case "sendtogr"
        publishFrame(mh);
        return
    case "clearbuffer"
        mh.cmdList = {};
        frameItems('clear');
        return
    case "seteye"
        mh.sceneSetEye = 1;
        return
end

% Playback control is a ONE-SHOT: it changes the renderer's state instead of
% describing the current picture. A drawing command may be dropped safely
% because the next frame draws it again, but a dropped PlayMovie never comes
% back - and the renderer only ever reads the NEWEST frame, so a command
% carried by exactly one frame is almost always skipped. One-shots therefore
% ride in every frame, each tagged with a token, and the renderer runs each
% token once, in order.
%
%   mh.Screen('PlayMovie',         mh, mov, rate)   start / pause (rate 0)
%   mh.Screen('CloseMovie',        mh, mov)         pause; playback resumes
%                                                   where it stopped
%   mh.Screen('SetMovieTimeIndex', mh, mov, secs)   seek, e.g. 0 to restart
args = varargin;
if numel(args) >= 2
    args{2} = windowToken(args{2});
end
tag = '';
if numel(args) >= 4 && (ischar(args{end-1}) || isstring(args{end-1})) && strcmpi(args{end-1}, 'Tag')
    tag = char(args{end});          % timestamp this item; Psychtoolbox never sees the pair
    args(end-1:end) = [];
end
if any(strcmpi(string(cmd), ["PlayMovie","CloseMovie","SetMovieTimeIndex"]))
    mh.oneShotSeq = mh.oneShotSeq + 1;
    s = struct('token', mh.oneShotSeq);
    s.cmd = args;
    mh.oneShots{end+1} = s;
    % Bounded ring rather than a clear at the trial boundary: a clear can
    % drop a token the renderer has not read yet, and one-shots are rare
    % enough that it can never fall this far behind.
    if numel(mh.oneShots) > 32
        mh.oneShots = mh.oneShots(end-31:end);
    end
    return
end
if ischar(args{min(2, end)}) && any(strcmp(args{min(2, end)}, {'both', 'display'}))
    frameItems('draw', args, tag);  % what the animal sees, for stimulus timing
end
mh.cmdList{end+1} = args;
end

% =========================================================================
function publishFrame(mh)
% Every published frame gets an ID and a generation timestamp, and lists the
% items it draws on the display (frameItems). The ID is the join key: the
% renderer records which frame each flip showed, so the change log kept here
% (when each item was asked for) meets the flips that showed it
% (buildStimulusTiming).
% GetSecs (PTB, monotonic, 0.48 us resolution) is the clock of every live
% time in a trial, and of the renderer's flip timestamps; trialRecord puts
% them all on the trial's timeline when the trial is saved.
tGen = GetSecs;
mh.sceneSeq = mh.sceneSeq + 1;
seq = mh.sceneSeq;
state = char(mh.activestatename);
[tagNames, tagKinds, tagRects, changes] = frameItems('take', state);

frame = struct( ...
    'seq',          seq, ...
    'tGenerated',   tGen, ...
    'trialStarted', logical(mh.trialstarted), ...
    'stateName',    state, ...
    'setEye',       logical(mh.sceneSetEye), ...
    'resources',    {mh.resourceDecl}, ...
    'oneShots',     {mh.oneShots}, ...
    'cmds',         {mh.cmdList});
if ~isempty(tagNames)                   % items drawn on the display (none: fields left out)
    frame.tagNames = tagNames;
    frame.tagKinds = tagKinds;
    frame.tagRects = tagRects;
end

sceneWrite(mh.sceneMap, seq, frame);

% The "requested" side of data.stimulus_events: every item appearing or
% disappearing, and every state change (the photodiode square changes colour
% on each), with this frame's ID and time. Rare, so grown on demand.
for j = 1:size(changes, 1)
    n = mh.stimReqN + 1;
    mh.stimReqTag{n}   = changes{j, 1};
    mh.stimReqKind{n}  = changes{j, 2};
    mh.stimReqEvent{n} = changes{j, 3};
    mh.stimReqState{n} = state;
    mh.stimReqSeq(n)   = seq;
    mh.stimReqTime(n)  = tGen;
    mh.stimReqN        = n;
end

mh.cmdList     = {};
mh.sceneSetEye = 0;
end

% =========================================================================
function tok = windowToken(w)
% Reduce the window argument to a small token the renderer can resolve.
% Tasks pass the internal object itself to mean "both windows"; serialising
% that object would be enormous and pointless.
if isobject(w) || isa(w,'internal')
    tok = 'both';
    return
end
if ischar(w) || isstring(w)
    switch lower(string(w))
        case "monitoronly",  tok = 'monitor';
        case "displayonly",  tok = 'display';
        case "windowptr",    tok = 'both';
        otherwise,           tok = w;    % not a window selector; pass through
    end
    return
end
tok = w;
end
