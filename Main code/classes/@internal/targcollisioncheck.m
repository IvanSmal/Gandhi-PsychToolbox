function out=targcollisioncheck(obj,t1,t2)
if obj.coltimer==0 || obj.coltimer==100
    t1pos=obj.trialtarg(t1,'getpos');
    t2pos=obj.trialtarg(t2,'getpos');

    t1x=t1pos(1):t1pos(3);
    t2x=t2pos(1):t2pos(3);

    t1y=t1pos(2):t1pos(4);
    t2y=t2pos(2):t2pos(4);

    if any(ismember(t1x,t2x)) && any(ismember(t1y,t2y))
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