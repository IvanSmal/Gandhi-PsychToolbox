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
% token once.
args = varargin;
if numel(args) >= 2
    args{2} = windowToken(args{2});
end
if any(strcmpi(string(cmd), ["PlayMovie","CloseMovie"]))
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
mh.cmdList{end+1} = args;
end

% =========================================================================
function publishFrame(mh)
% Every published frame gets an ID and a generation timestamp. The ID is the
% join key: the renderer records which IDs actually reached the screen, so
% latency = flipTime(id) - tGenerated(id) for the frames that were displayed.
% GetSecs (PTB, monotonic, 0.48 us resolution) is used on BOTH sides -
% getsecs is wall-clock seconds-since-midnight and is not comparable to
% Psychtoolbox flip timestamps.
tGen = GetSecs;
mh.sceneSeq = mh.sceneSeq + 1;
seq = mh.sceneSeq;

frame = struct( ...
    'seq',          seq, ...
    'tGenerated',   tGen, ...
    'trialStarted', logical(mh.trialstarted), ...
    'stateName',    char(mh.activestatename), ...
    'setEye',       logical(mh.sceneSetEye), ...
    'resources',    {mh.resourceDecl}, ...
    'oneShots',     {mh.oneShots}, ...
    'cmds',         {mh.cmdList});

sceneWrite(mh.sceneMap, seq, frame);

% log EVERY generated command, not only the ones that get displayed
n = mh.cmdLogN + 1;
if n > numel(mh.cmdLogId)
    mh.cmdLogId(2*numel(mh.cmdLogId))     = 0;   % geometric growth
    mh.cmdLogTime(2*numel(mh.cmdLogTime)) = 0;
end
mh.cmdLogId(n)   = seq;
mh.cmdLogTime(n) = tGen;
mh.cmdLogN       = n;

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
