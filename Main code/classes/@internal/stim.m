function stim(mh)
%Trigger stim script
if ~mh.stimmed
    xippmex('digout', 2, mh.stimflip)
    mh.stimflip=abs(mh.stimflip-1);
    mh.stimmed=1;
end
end

