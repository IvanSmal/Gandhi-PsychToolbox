function mh=reward(mh,int)
if mh.rew.rewon==0
    mh.rew.rewstart=getsecs;
    mh.rew.rewon=1;
    sound(sin(1:1e6),3000);
    mh.rew.int=int;
end
end