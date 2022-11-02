function Main_function(app)

% example of experiment script
cal=1;
addpath(genpath(fileparts(which('Main_script')))); % add subfolders

%% start parallel computing
% p = parpool(2);
%% set up daq
devlist=daqlist;
dq=daq('ni');
addinput(dq,devlist.DeviceID,"ai0","Voltage")
addinput(dq,devlist.DeviceID,"ai1","Voltage")
dq.Rate=1000;

%% set all the PsychToolbox and daq parameters

Screen('Preference', 'SkipSyncTests', 2);
Priority(2);

%

% Clear the workspace and the screen
sca;
close all;
% clear;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% Get the screen numbers
w.screens = Screen('Screens');

% Draw to the external screen if avaliable
w.screenNumber = max(w.screens);

% Define black and white
w.white = WhiteIndex(w.screenNumber);
w.black = BlackIndex(w.screenNumber);

% Open an on screen window
[w.window_main, w.windowRect] = PsychImaging('OpenWindow', w.screenNumber, w.black);

% Get the size of the on screen window
[w.screenXpixels, w.screenYpixels] = Screen('WindowSize', w.window_main);

%get size of the screen
[w.width, w.height]=Screen('DisplaySize',  w.screenNumber);

% set up a monitoring window
w.window_monitor=PsychImaging('OpenWindow', 1, w.black,w.windowRect/4);

% Get the centre coordinate of the window
[w.xCenter, w.yCenter] = RectCenter(w.windowRect);

%% set trial parameters

% Make a base Rect of 100 by 100 pixels
params.baseRect = [0 0 100 100];

% Set the colors
params.allColors = [1 1 0];

% Set random x and y coordinates around the center
params.addX=[300, -300, 0];
params.addY=[300,-300, 0];

% Set tolerance window

params.twindow=100;

% Retreive the maximum priority number and set max priority
topPriorityLevel = MaxPriority(w.window_main);
Priority(topPriorityLevel);

% Set your trial time and iti. Note: you can set these within trial
% functions
params.T0_waitsecs = 10;
params.T0_holdsecs = 1;

params.T1_waitsecs = 5;
params.T1_holdsecs = 1;

params.iti=0.5;

% photodiode position
params.diode(:,1)=[0,0,50,50];

% start target
params.targ0 = CenterRectOnPointd(params.baseRect,w.xCenter,w.yCenter);

% start trial
params.trial=0;

% FOR GABOR TRIALS BELOW
% gabor size and stuff
params.gabor.size=[400 400];
params.gabor.orientation = [0 45 90 135 180 225 270 315];
params.gabor.contrast = 0.8;
params.gabor.aspectRatio = 1.0;
params.gabor.phase = 10;
params.gabor.sigma = 400/5;
params.gabor.freq=3/400;

backgroundOffset = [0 0 0 0];

% make a gabor texture
params.gabor.GabTex = CreateProceduralGabor(w.window_main, params.gabor.size(1),...
    params.gabor.size(2), [],...
    backgroundOffset, 1, 1);    % make gabor texture
%% Calibrate eye voltage
if cal
    [w.minEye, w.maxEye]=calibrate(w,dq);
end

%% call trial types
if ~isfield(params,'trialnum')
    params.trialnum=0;
end
    savestate(params)

while ~app.STOPButton.Value
    params.trialnum=params.trialnum+1;
    start(dq, 'continuous') % start data collection

    r=1;
        if r==1
            [d(params.trialnum).params,w]=center_out(params,w,dq);
        elseif r==2
            [d(params.trialnum).params,w]=gabors_center_8rotations(params,w,dq);
        elseif r==3
            [d(params.trial).params,w]=movie(params,w);
        end

    Screen('FillRect', w.window_main, [0;0;0], params.diode);
    Screen('Flip', w.window_main); % incase diode was on at the end, turn it of for a frame

    pause(params.iti) %wait ITI
    d(params.trialnum).daq=read(dq,'all','OutputFormat','Matrix');
    stop(dq)
end
%% ending procedure
stpstr=sprintf('%s\n%s',string(get(app.ParametersTextArea,'Value'))...
    , 'now stopping please wait');
set(app.ParametersTextArea,'Value',stpstr);
set(app.STOPButton,'enable','off')



set(app.STOPButton,'Value',0)

end
