function m = sceneOpen(writable, p)
%SCENEOPEN Open the shared scene slot (a sceneSlot handle).
%   m = sceneOpen(true)   writer (the state machine)
%   m = sceneOpen(false)  reader (GraphicsHandler)
if nargin < 2 || isempty(p), p = scenePath(); end
if nargin < 1, writable = false; end
L = sceneLayout();
if ~isfile(p), sceneCreate(p); end
d = dir(p);
if d.bytes ~= L.CAP
    sceneCreate(p);   % capacity changed (layout revision): rebuild
end
m = sceneSlot(p, writable);
end
