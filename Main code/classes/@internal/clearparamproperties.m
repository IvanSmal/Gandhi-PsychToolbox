function mh=clearparamproperties(mh)
%CLEARPARAMPROPERTIES Drop everything the previous parameter file declared.
%   Called immediately before a parameter file is run, so whatever it does
%   not re-declare is genuinely gone rather than lingering from the last one.
PARAMPROPERTIES = {'intervals', 'targets'};
for i=1:length(PARAMPROPERTIES)
    mh.(PARAMPROPERTIES{i})=[];
end

% Texture and movie declarations are parameter-file state too. Leaving them
% in place meant every stale declaration kept riding in every published
% frame, and logical ids kept climbing across reloads. Resetting is safe
% because the renderer validates an id against the path it was loaded from
% before reusing a cached handle.
mh.textures     = struct();
mh.movies       = struct();
mh.resourceIds  = struct();
mh.resourceDecl = {};
mh.nextResId    = 0;
end
