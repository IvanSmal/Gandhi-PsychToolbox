function response = WaitForGraphics(mh)
mh.graphicssent=0;
tic
while toc<1 && mh.graphicssent==0
        str=('writeline(graphicsport,''mh.graphicssent=1;'',''0.0.0.0'',2020);');
        mh.evalgraphics(str);
        com=readline(mh.graphicsport);
        tic
        try %this is a dirty way to make sure 'com' is evaluatable
            eval(com);
        catch
        end
end
if mh.graphicssent==1
    response = 1;
elseif mh.graphicssent==0
    response = 0;
end

end