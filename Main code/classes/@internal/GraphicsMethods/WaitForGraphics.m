function WaitForGraphics(mh)
mh.graphicssent=0;
while mh.graphicssent==0
    str=('writeline(graphicsport,''mh.graphicssent=1;'',''0.0.0.0'',2020);');
    mh.evalgraphics(str);
    com=readline(mh.graphicsport);
    try %this is a dirty way to make sure 'com' is evaluatable
        eval(com);
    catch
    end
end
end