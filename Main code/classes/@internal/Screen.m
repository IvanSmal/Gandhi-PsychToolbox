function varargout = Screen(mh, varargin)
%SCREEN Psychtoolbox-style drawing that publishes to the shared scene slot.
%
%   Task files keep the Psychtoolbox syntax they have always used:
%       mh.Screen('FillOval', mh, color, rect)
%       mh.Screen('sendtogr')
%
%   What changed is what happens underneath. This used to serialise every
%   call into MATLAB source text and ship it over UDP for GraphicsHandler to
%   eval - about 1 ms per writeline, three per iteration, which was 77% of
%   the state-machine loop. Now each call fills fields in a fixed binary
%   scene, and 'sendtogr' publishes the whole scene with ONE contiguous
%   write (~39 us measured).
%
%   The scene is a LATEST-VALUE SLOT, not a queue: the state machine
%   overwrites it as fast as it likes and never waits, while GraphicsHandler
%   reads whichever scene is current when it is ready to draw. Scenes the
%   renderer skipped were never displayable, so skipping them is correct and
%   nothing can back up.
%
%   Shape codes: 1 FillOval, 2 FillRect, 3 FrameOval, 4 FrameRect

L = sceneLayout();

% ---- lazily attach to the slot -----------------------------------------
if isempty(mh.sceneMap)
    mh.sceneMap = sceneOpen(true);
    mh.sceneVec = zeros(L.N,1);
end

cmd = varargin{1};
if ~(ischar(cmd) || isstring(cmd)), return; end

switch lower(string(cmd))
    case "sendtogr"
        publishScene(mh, L);
        return
    case "clearbuffer"
        mh.nTargetsAcc = 0; mh.nOverlayAcc = 0;
        return
    case "seteye"
        mh.sceneSetEye = 1;
        return
    case {"playmovie","closemovie","drawtexture","openmovie","setmovietimeindex"}
        % Movies are handled renderer-side; wired up separately.
        return
end

% ---- drawing primitive --------------------------------------------------
shape = shapeCode(cmd);
if shape == 0 || numel(varargin) < 4, return; end

isOverlay = (ischar(varargin{2}) || isstring(varargin{2})) && ...
            strcmpi(varargin{2}, 'monitoronly');

colors = normaliseRows(varargin{3}, 3);
rects  = normaliseRows(varargin{4}, 4);
if isempty(rects), return; end
penWidth = 1;
if numel(varargin) >= 5 && isnumeric(varargin{5}) && isscalar(varargin{5})
    penWidth = varargin{5};
end

n = size(rects,1);
for k = 1:n
    rect = rects(k,:);
    if size(colors,1) >= k, col = colors(k,:); else, col = colors(1,:); end
    if isOverlay
        if mh.nOverlayAcc >= L.MAX_OVERLAY, continue; end
        mh.nOverlayAcc = mh.nOverlayAcc + 1;
        base = L.OVERLAYS(1) + (mh.nOverlayAcc-1)*L.OVERLAY_WIDTH;
        mh.sceneVec(base:base+9) = [1, shape, rect(:).', col(:).', penWidth];
    else
        if mh.nTargetsAcc >= L.MAX_TARGETS, continue; end
        mh.nTargetsAcc = mh.nTargetsAcc + 1;
        base = L.TARGETS(1) + (mh.nTargetsAcc-1)*L.TARGET_WIDTH;
        mh.sceneVec(base:base+8) = [1, shape, rect(:).', col(:).'];
    end
end
end

% =========================================================================
function publishScene(mh, L)
% One contiguous write. Sequence number is duplicated at both ends so a
% reader catching a partial write sees a stale tail and retries.
v = mh.sceneVec;

v(L.TRIALSTARTED) = mh.trialstarted;
v(L.NTARGETS)     = mh.nTargetsAcc;
v(L.NOVERLAY)     = mh.nOverlayAcc;
v(L.MOVIECMD)     = 0;
v(L.MOVIEID)      = 0;

nm = char(mh.activestatename);
nm = nm(1:min(numel(nm), L.NAME_CHARS));
nameVec = zeros(1, L.NAME_CHARS);
nameVec(1:numel(nm)) = double(nm);
v(L.NAME) = nameVec;

v(L.RESERVED(1)) = mh.sceneSetEye;
mh.sceneSetEye = 0;

% blank any slots not used this frame, so stale primitives never linger
for k = mh.nTargetsAcc+1 : L.MAX_TARGETS
    base = L.TARGETS(1) + (k-1)*L.TARGET_WIDTH;
    v(base) = 0;
end
for k = mh.nOverlayAcc+1 : L.MAX_OVERLAY
    base = L.OVERLAYS(1) + (k-1)*L.OVERLAY_WIDTH;
    v(base) = 0;
end

mh.sceneSeq = mh.sceneSeq + 1;
v(L.SEQ_HEAD) = mh.sceneSeq;
v(L.SEQ_TAIL) = mh.sceneSeq;

mh.sceneVec = v;
mh.sceneMap.Data.s = v;          % single contiguous assignment

mh.nTargetsAcc = 0;
mh.nOverlayAcc = 0;
end

% =========================================================================
function c = shapeCode(cmd)
switch lower(string(cmd))
    case "filloval",  c = 1;
    case "fillrect",  c = 2;
    case "frameoval", c = 3;
    case "framerect", c = 4;
    otherwise,        c = 0;
end
end

% =========================================================================
function out = normaliseRows(x, width)
% Accept a 1xW row, an NxW stack, or a WxN stack (Psychtoolbox vectorised
% form, which checkeye uses to draw several frame ovals in one call).
out = [];
if isempty(x) || ~isnumeric(x), return; end
if size(x,2) == width
    out = x;
elseif size(x,1) == width
    out = x.';
elseif numel(x) == width
    out = reshape(x,1,width);
end
end
