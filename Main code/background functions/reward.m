function reward(internal, int)
    if internal.rewon==0
        internal.rewstart=cputime;
        internal.rewon=1;
    end
    if internal.rewon==1 && cputime<internal.rewstart+int
        xippmex('digout',4,1);
    elseif internal.rewon==1 && cputime>internal.rewstart+int
        xippmex('digout',4,0);
        disp(['reward t: ' cputime-internal.rewstart])
    end
end