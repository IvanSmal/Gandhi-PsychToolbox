function addmovie(mh, name, moviePath)
%ADDMOVIE Declare a movie resource, for use in a parameter file.
%   Mirrors addtarg/addint: declare it once in the parameter file, then grab
%   it in the task's setup block with getmovie.
%
%       mh.addmovie('intro', '/path/to/movie.mp4');
%
%   The movie is opened by GraphicsHandler, which owns the window and
%   advances playback one frame per flip at its own refresh rate.
mh.movies.(name) = char(moviePath);
end
