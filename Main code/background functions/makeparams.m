function mh=makeparams(mh)
%% non task-specific info

% Set your intervals
mh.addint('T0_reach',1)
mh.addint('T0_hold',2)
mh.addint('T1_reach',1)
mh.addint('T1_hold',2)

mh.addint('iti',2)

mh.addint('reward',0.2)

% Set your targets. if doing target logic inside the trial, don't forget to
% add a targ object into your trial structure
center=[mh.xCenter,mh.yCenter];
mh.addtarg('T0','position',center, 'color', [0 1 0])
mh.addtarg('T1','position',[100 50; -50 -100; 10 80])
mh.addtarg('T0_moving','position',center,'speed',100,'direction',90, 'color', [0 1 0])
mh.addtarg('T1_moving','position',center,'speed',200,'direction',180, 'color', [1 1 0])

end