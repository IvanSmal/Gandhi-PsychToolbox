function L = sceneLayout()
%SCENELAYOUT Fixed binary layout of the shared scene slot.
%   One contiguous double vector. The sequence counter is duplicated at the
%   FIRST and LAST element: a reader that catches a partially-completed
%   forward write sees a stale tail and retries. Everything is fixed-size,
%   so a write is a single assignment with no allocation or parsing.
L.MAX_TARGETS  = 16;
L.MAX_OVERLAY  = 8;     % monitor-only annotations (checkeye / plotwindow)
L.NAME_CHARS   = 32;    % state name, zero-padded char codes
L.TARGET_WIDTH = 9;     % visible shape x1 y1 x2 y2 r g b
L.OVERLAY_WIDTH= 10;    % visible shape x1 y1 x2 y2 r g b penWidth

i = 1;
L.SEQ_HEAD = i;                       i = i + 1;
L.TRIALSTARTED = i;                   i = i + 1;
L.DIODE = i:i+2;                      i = i + 3;
L.NTARGETS = i;                       i = i + 1;
L.NOVERLAY = i;                       i = i + 1;
L.MOVIECMD = i;                       i = i + 1;   % 0 none, 1 play, 2 close
L.MOVIEID  = i;                       i = i + 1;
L.RESERVED = i:i+5;                   i = i + 6;
L.NAME     = i:i+L.NAME_CHARS-1;      i = i + L.NAME_CHARS;
L.TARGETS  = i:i+L.MAX_TARGETS*L.TARGET_WIDTH-1;   i = i + L.MAX_TARGETS*L.TARGET_WIDTH;
L.OVERLAYS = i:i+L.MAX_OVERLAY*L.OVERLAY_WIDTH-1;  i = i + L.MAX_OVERLAY*L.OVERLAY_WIDTH;
L.SEQ_TAIL = i;
L.N = i;
end
