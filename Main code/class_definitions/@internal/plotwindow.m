function plotwindow(mh,targ, pos)
windowsize_all=deg2pix([mh.trial.targets.(targ).window mh.trial.targets.(targ).window],'size');
radius=windowsize_all(3);
targetlocation = pos;
centerx=(targetlocation(3)+targetlocation(1))/2;
centery=(targetlocation(4)+targetlocation(2))/2;
squarepos=round([centerx-radius centery-radius centerx+radius centery+radius]);
mh.Screen('FrameOval','monitoronly',[1 1 1],squarepos);
end