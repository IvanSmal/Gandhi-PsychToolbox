Screen('Preference', 'SkipSyncTests', 1)
%% basic setup
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
allColors = [1 0 0];

% Set random x and y coordinates around the center
addX=[300, -300, 0];
addY=[300,-300, 0];

% Measure the vertical refresh rate of the monitor
ifi = Screen('GetFlipInterval', window_main);

% Retreive the maximum priority number and set max priority
topPriorityLevel = MaxPriority(window_main);
Priority(topPriorityLevel);

% Here we use to a waitframes number to flip at a rate not
% equal to the monitors refreash rate. For this example, once per second,
% to the nearest frame
flipSecs = 15;
waitframes = round(flipSecs / ifi);
iti=round(0.5 / ifi);

% photodiode position
diode(:,1)=[0,0,50,50];

% start target
targ0 = CenterRectOnPointd(baseRect,xCenter,yCenter);

%% running trials
% Flip outside of the loop to get a time stamp
vbl = Screen('Flip', window_main);

% display random targets around the center
while ~KbCheck

    % Make our rectangle coordinates
    
    targ1(:, 1) = CenterRectOnPointd(baseRect,...
        xCenter+addX(randi(length(addX))),...
        yCenter+addY(randi(length(addY))));

% START TARGET
    for frames=1:waitframes
        % get cursor position
        [xmouse, ymouse, buttons] = GetMouse(window_main);
        xmouse = min(xmouse, screenXpixels);
        ymouse = min(ymouse, screenYpixels);

        if ~hitdetect([xmouse,ymouse],targ0) && ~KbCheck
            % Draw the rect to the screen
            Screen('FillRect', window_main, [allColors]', targ0);
            Screen('FillRect', window_main, [1 1 1]', diode);
            Screen('DrawDots', window_main, [xmouse ymouse], 10, white, [], 2);
            
            % Flip to the screen
            vbl=Screen('Flip', window_main);
        else
            break
        end
    end

% TARG 1

    for frames=1:waitframes
        % get cursor position
        [xmouse, ymouse, buttons] = GetMouse(window_main);
        xmouse = min(xmouse, screenXpixels);
        ymouse = min(ymouse, screenYpixels);

        if ~hitdetect([xmouse,ymouse],targ1) && ~KbCheck
            % Draw the rect to the screen
            Screen('FillRect', window_main, [allColors]', targ1);
            Screen('FillRect', window_main, [1 1 1]', diode);
            Screen('DrawDots', window_main, [xmouse ymouse], 10, white, [], 2);
            
            % Flip to the screen
            vbl=Screen('Flip', window_main);
        else
            break
        end
    end

% ITI    
    for frames=1:60
        Screen('WindowSize', window_main)
    
        vbl=Screen('Flip', window_main);
    end

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

