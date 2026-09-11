function p = sceneCreate(p)
%SCENECREATE Create (or zero) the shared scene slot.
if nargin < 1 || isempty(p), p = scenePath(); end
L = sceneLayout();
fid = fopen(p,'w');
if fid < 0, error('sceneCreate:open','cannot create scene slot "%s"', p); end
fwrite(fid, zeros(L.CAP,1), 'double');
fclose(fid);
end
