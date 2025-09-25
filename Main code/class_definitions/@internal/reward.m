function mh=reward(mh,int,identifier)
if ~exist('identifier','var')
    identifier=0;
end

if isnumeric(int)
    duration = int;
else
    duration = int.duration;
end
writeline(mh.rewardport,num2str([duration identifier]),'0.0.0.0',2022);
% mh.makesound('reward',300,3,1);
mh.rewardcount=mh.rewardcount+1;
% app.insToTxtbox(['Requested reward of: ' num2str(getsecs-mh.rew.rewstart) 's']);
end