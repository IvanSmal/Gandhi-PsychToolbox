function stim(mh)
%Trigger stim script
if ~mh.stimmed
    write(mh.graphicsport,1,'192.168.42.2',2028)
    mh.stimflip=abs(mh.stimflip-1);
    mh.stimmed=1;
end
end

