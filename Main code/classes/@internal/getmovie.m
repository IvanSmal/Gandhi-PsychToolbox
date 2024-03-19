function getmovie(mh, moviepath,varargin)
mh.movie=Screen('OpenMovie',mh.window_main,moviepath,varargin{:});
end