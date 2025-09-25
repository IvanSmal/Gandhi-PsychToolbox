function evalgraphics(obj,command)
matlabUDP2('send',obj.graphicsport,join(['execute' command]));
end