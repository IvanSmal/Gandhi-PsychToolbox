function [v, ok] = sceneRead(m, maxRetry)
%SCENEREAD Newest COMPLETE scene, or ok=false if it kept tearing.
%   The sequence counter is duplicated at both ends of the buffer. A reader
%   that catches a partially-completed forward write sees a stale tail and
%   retries, so it can never draw a half-updated scene.
if nargin < 2, maxRetry = 8; end
L = sceneLayout();
ok = false; v = [];
for k = 1:maxRetry
    v = m.Data.s;
    if v(L.SEQ_HEAD) == v(L.SEQ_TAIL) && v(L.SEQ_HEAD) > 0
        ok = true; return
    end
end
end
