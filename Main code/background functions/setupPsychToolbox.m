function in=setupPsychToolbox(in)
    Screen('Preference', 'SkipSyncTests', 2);
    Priority(2);
    
    % Clear the workspace and the screen
    sca;
    close all;
    
    % Here we call some default settings for setting up Psychtoolbox
    PsychDefaultSetup(2);
    
    % Get the screen numbers
    in.screens = Screen('Screens');

    screenNum=max(in.screens);
    
    % Define black and white
    black = BlackIndex(screenNum);
    
    % Open an on screen window
    [in.window_main, in.windowRect] = PsychImaging('OpenWindow', screenNum, black);
    

    % Get the size of the on screen window
    [in.screenXpixels, in.screenYpixels] = Screen('WindowSize', in.window_main);
    
    %get size of the screen
    [in.width, in.height]=Screen('DisplaySize',  screenNum);
%%
    
    % set up a monitoring window
    in.window_monitor=PsychImaging('OpenWindow', 1, black,in.windowRect/4);
    
    % Get the centre coordinate of the window
    [in.xCenter, in.yCenter] = RectCenter(in.windowRect);

    % make the first trial run
    in.runtrial=1;

    %reward initial state off
    in.rewon=0;
end