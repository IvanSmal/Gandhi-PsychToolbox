Screen('Preference', 'SkipSyncTests', 2);
%% basic setup
Priority(2);

%
data=struct();

% Clear the workspace and the screen
sca;
close all;
clear;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% Get the screen numbers
screens = Screen('Screens');

% Draw to the external screen if avaliable
screenNumber = max(screens);

% Define black and white
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);

% Open an on screen window
[window_main, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Get the size of the on screen window
[screenXpixels, screenYpixels] = Screen('WindowSize', window_main);

% Get the centre coordinate of the window
[xCenter, yCenter] = RectCenter(windowRect);

%prep the mouse
SetMouse(0, 0, window_main);
HideCursor(window_main)

%% trial parameters
% Make a base Rect of 200 by 200 pixels
baseRect = [0 0 50 50];

% Set the colors to Red, Green and Blue
allColors = [1 1 0];

% Set random x and y coordinates around the center
addX=[300, -500, 0];
addY=[300,-300, 0];

% Measure the vertical refresh rate of the monitor
ifi = Screen('GetFlipInterval', window_main);

% Retreive the maximum priority number and set max priority
topPriorityLevel = MaxPriority(window_main);
Priority(topPriorityLevel);

% Set your trial time and iti
waitsecs = 5;

iti=0.5;

% photodiode position
diode(:,1)=[0,0,50,50];

% start target
targ0 = CenterRectOnPointd(baseRect,xCenter,yCenter);

% start trial
trial=0;
%% running trials
% Flip outside of the loop to get a time stamp
vbl = Screen('Flip', window_main);

% display random targets around the center

while 1%~KbCheck
    statecount=0; %reset statecount
    
    s=GetSecs; %get start trial time

    d_col=diodecolor(statecount);
    Screen('FillRect', window_main, d_col, diode);

    trial=trial+1; %count the trial

    Screen('Flip', window_main); %flash diode for start trial
    data(trial).state.START=GetSecs-s; %record some info

    midx=0; %get mouse loop index

    % Make our random Targ1 coordinates

    targ1(:, 1) = CenterRectOnPointd(baseRect,...
        xCenter+addX(randi(length(addX))),...
        yCenter+addY(randi(length(addY))));

    success=1; % assume success until failure

    % START TARGET
    tp=GetSecs;
    statecount=statecount+1;
    d_col=diodecolor(statecount);

    while GetSecs<tp+waitsecs

        data(trial).state.T0=GetSecs-s; %record some info

        %log mouse movement
        midx=midx+1;
        [mpos(1,midx), mpos(2,midx), mpos(3,midx)]=mousepos(window_main,s);

        % get cursor position
        [xmouse, ymouse]=mousepos(window_main,s);

        if ~hitdetect([xmouse,ymouse],targ0) && ~KbCheck
            % Draw the rect to the screen
            Screen('FillRect', window_main, [allColors]', targ0);
            Screen('FillRect', window_main, d_col, diode);
            Screen('DrawDots', window_main, [xmouse ymouse], 10, white, [], 2);

            % Flip to the screen
            vbl=Screen('Flip', window_main);
            cont=0;
        else
            cont=1;
            break
        end
    end

    % TARG 1
    if cont
        statecount=statecount+1;
        d_col=diodecolor(statecount);

        tp=GetSecs;
        while GetSecs< tp+waitsecs

            data(trial).state.T1=GetSecs-s; %record some info

            %log mouse movement
            midx=midx+1;
            [mpos(1,midx), mpos(2,midx), mpos(3,midx)]=mousepos(window_main,s);

            % get cursor position
            [xmouse, ymouse, buttons] = GetMouse(window_main);
            xmouse = min(xmouse, screenXpixels);
            ymouse = min(ymouse, screenYpixels);

            if ~hitdetect([xmouse,ymouse],targ1) && ~KbCheck
                % Draw the rect to the screen
                Screen('FillRect', window_main, [allColors]', targ1);
                Screen('FillRect', window_main, d_col, diode);
                Screen('DrawDots', window_main, [xmouse ymouse], 10, white, [], 2);

                % Flip to the screen
                vbl=Screen('Flip', window_main);
                success=0;
            else
                success=0;
                break
            end
        end
    else
        success=0;
    end

    % ITI
    tp=GetSecs;
    statecount=statecount+1;
    d_col=diodecolor(statecount);

    while GetSecs< tp+iti

        data(trial).state.ITI=GetSecs-s; %record some info

        %log mouse movement
        midx=midx+1;
        [mpos(1,midx), mpos(2,midx), mpos(3,midx)]=mousepos(window_main,s);

        Screen('WindowSize', window_main)
        Screen('FillRect', window_main, d_col, diode);

        vbl=Screen('Flip', window_main);
    end
    
    Screen('FillRect', window_main, [0;0;0], diode);
    Screen('Flip', window_main); % incase diode was on at the end, turn it of for a frame

    data(trial).mousepos=mpos;
    data(trial).success=success;
    clear mpos
    data(trial).state.END=GetSecs-s;
end

% Clear the screen
sca;

%% extra functions
function out=hitdetect(cursor,target)
if cursor(1)>=target(1) && cursor(2) >= target(2) &&...
        cursor(1)<target(3) && cursor(2)< target(4)
    out=1;
else
    out=0;
end
end

function [xmouse, ymouse, t]=mousepos(window,s)
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

[xmouse, ymouse] = GetMouse(window);
xmouse = min(xmouse, screenXpixels);
ymouse = min(ymouse, screenYpixels);

t=GetSecs-s;
end

function d_col=diodecolor(statecount)
    if rem(statecount,2)
        d_col=[1;1;1];
    else
        d_col=[0;0;0];
    end
end