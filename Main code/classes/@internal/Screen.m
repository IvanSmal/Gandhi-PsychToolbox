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

% Any other call is a drawing command: stash it verbatim, with the window
% argument reduced to a token. The internal object must never be serialised.
args = varargin;
if numel(args) >= 2
    args{2} = windowToken(args{2});
end
mh.cmdList{end+1} = args;
end

% =========================================================================
function publishFrame(mh)
frame = struct( ...
    'trialStarted', logical(mh.trialstarted), ...
    'stateName',    char(mh.activestatename), ...
    'setEye',       logical(mh.sceneSetEye), ...
    'cmds',         {mh.cmdList});

mh.sceneSeq = mh.sceneSeq + 1;
sceneWrite(mh.sceneMap, mh.sceneSeq, frame);

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
