function ref = getmovie(mh, name)
%GETMOVIE Grab a declared movie for this trial. Use in the setup block.
%
%       mov = mh.getmovie('intro');                      % once per trial
%       mh.Screen('PlayMovie',   mh, mov, 1);            % start playback
%       mh.Screen('DrawTexture', mh, mov, [], rect);     % draw current frame
%
%   Returns a lightweight reference. The movie is opened and advanced by
%   GraphicsHandler, which owns the window; the previous version of this
%   function tried to open it in the state machine's process against a
%   window property that does not exist, so it could never have worked.
if ~isfield(mh.movies, name)
    error('getmovie:undeclared', ...
        'movie "%s" was never declared. Add mh.addmovie(''%s'', path) to the parameter file.', name, name);
end
ref = declareResource(mh, name, 'movie', mh.movies.(name));
end
