function m = sceneOpen(writable, p)
%SCENEOPEN Map the shared scene slot.
%   m = sceneOpen(true)   writer (the state machine)
%   m = sceneOpen(false)  reader (GraphicsHandler)
if nargin < 2 || isempty(p), p = scenePath(); end
if nargin < 1, writable = false; end
L = sceneLayout();
if ~isfile(p), sceneCreate(p); end
m = memmapfile(p, 'Format', {'double',[L.N 1],'s'}, 'Writable', logical(writable));
end
