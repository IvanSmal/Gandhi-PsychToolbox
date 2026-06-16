function response = WaitForGraphics(mh)
mh.graphicssent=0;
t = tic;
while toc(t) < 1 && mh.graphicssent==0
    % Ask GraphicsHandler to echo back a flag via matlabUDP_gandhi
    str = 'matlabUDP_gandhi(''send'', graphicsport, ''mh.graphicssent=1;'');';
    mh.evalgraphics(str);
    com = matlabUDP_gandhi('receive', mh.graphicsport);
    if ~isempty(com)
        try
            eval(com);
        catch
        end
    end
end
if mh.graphicssent==1
    response = 1;
else
    response = 0;
end
end