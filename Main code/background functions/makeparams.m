function e=makeparams(inter)
%% non task-specific info
e=experiment; % initialize an object

% set subject name
e.subject_name=get(inter.app.SubjectNameEditField,'Value');

% set recording directory
e.dir=get(inter.app.Dir,'Value');

% Set your intervals
addint(e,'T0_reach',5)
addint(e,'T0_hold',3)

addint(e,'iti',1)

addint(e,'reward',2)

% Set your targets
center=[inter.xCenter,inter.yCenter];
addtarg(e,'T0','position',center)
addtarg(e,'T1','position',[400 300; 200 100; 10 800])

%% center-out parameters
e.tasks.imageTrials.brightess=[];

%% gabor parameters
% gabor size and stuff
e.tasks.gabor.size=[400 400];
e.tasks.gabor.orientation = [0 45 90 135 180 225 270 315];
e.tasks.gabor.contrast = 0.8;
e.tasks.gabor.aspectRatio = 1.0;
e.tasks.gabor.phase = 10;
e.tasks.gabor.sigma = 400/5;
e.tasks.gabor.freq=3/400;

backgroundOffset = [0 0 0 0];

% make a gabor texture
e.tasks.gabor.GabTex = CreateProceduralGabor(inter.window_main, e.tasks.gabor.size(1),...
    e.tasks.gabor.size(2), [],...
    backgroundOffset, 1, 1);    % make gabor texture
end