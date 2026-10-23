function addtexture(mh, name, imagePath)
%ADDTEXTURE Declare an image resource, for use in a parameter file.
%   Mirrors addtarg/addint: declare it once in the parameter file, then grab
%   it in the task's setup block with gettexture.
%
%       mh.addtexture('face', '/path/to/face.jpg');
%
%   The image is loaded by GraphicsHandler, which owns the window - a
%   Psychtoolbox texture handle is only valid in the process that made it.
mh.textures.(name) = char(imagePath);
end
