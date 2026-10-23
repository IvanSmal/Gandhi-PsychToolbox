function ref = gettexture(mh, name)
%GETTEXTURE Grab a declared texture for this trial. Use in the setup block.
%
%       tex = mh.gettexture('face');                     % once per trial
%       mh.Screen('DrawTexture', mh, tex, [], rect);     % every frame
%
%   Returns a lightweight reference, not a Psychtoolbox handle: the real
%   handle lives in the renderer's process. The renderer resolves the
%   reference when it draws.
if ~isfield(mh.textures, name)
    error('gettexture:undeclared', ...
        'texture "%s" was never declared. Add mh.addtexture(''%s'', path) to the parameter file.', name, name);
end
ref = declareResource(mh, name, 'texture', mh.textures.(name));
end
