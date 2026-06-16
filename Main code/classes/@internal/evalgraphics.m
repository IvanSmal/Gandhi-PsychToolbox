function evalgraphics(obj, command)
matlabUDP_gandhi('send', obj.graphicsport, char(join(['execute' command])))
end