function e=makeparams(inter)
%% non task-specific info
e=experiment; % initialize the object
e.subject_name = inter.app.SubjectNameEditField.Value;
e.dir = inter.app.Dir.Value;

% Set your intervals
addint(e,'T0_reach',1)
addint(e,'T0_hold',2)
addint(e,'T1_reach',1)
addint(e,'T1_hold',2)

addint(e,'iti',2)

addint(e,'reward',0.2)

% Set your targets. if doing target logic inside the trial, don't forget to
% add a targ object into your trial structure
center=[inter.xCenter,inter.yCenter];
addtarg(e,'T0','position',center, 'color', [0 1 0])
addtarg(e,'T1','position',[100 50; -50 -100; 10 80])
addtarg(e,'T0_moving','position',center,'speed',5,'direction',90)

end