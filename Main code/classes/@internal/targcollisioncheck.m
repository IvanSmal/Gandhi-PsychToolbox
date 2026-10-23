function out=targcollisioncheck(obj,targAName,targBName)
if obj.coltimer==0 || obj.coltimer==100
    targAPos=obj.trialtarg(targAName,'getpos');
    targBPos=obj.trialtarg(targBName,'getpos');

    targAX=targAPos(1):targAPos(3);
    targBX=targBPos(1):targBPos(3);

    targAY=targAPos(2):targAPos(4);
    targBY=targBPos(2):targBPos(4);

    if any(ismember(targAX,targBX)) && any(ismember(targAY,targBY))
        out=1;
        obj.coltimer=obj.coltimer+1;
    else
        out=0;
        if obj.coltimer==100
            obj.coltimer=0;
        end
    end

elseif obj.coltimer==100
    obj.coltimer=0;
    out=0;
else
    obj.coltimer=obj.coltimer+1;
    out=0;
end
end
