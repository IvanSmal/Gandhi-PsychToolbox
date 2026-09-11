function ref = declareResource(mh, name, kind, path)
%DECLARERESOURCE Assign a logical id to a resource and queue its declaration.
%   The declaration list rides in EVERY published frame rather than being
%   sent once. It is tiny (an id, a kind and a path), and making it
%   idempotent removes any race over whether the renderer saw the frame that
%   happened to carry it.
key = [kind '_' name];
if ~isfield(mh.resourceIds, key)
    mh.nextResId = mh.nextResId + 1;
    mh.resourceIds.(key) = mh.nextResId;
    mh.resourceDecl{end+1} = struct('id', mh.nextResId, 'kind', kind, 'path', char(path));
end
ref = struct('resref', mh.resourceIds.(key));
end
