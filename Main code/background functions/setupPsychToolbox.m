function internal=setupPsychToolbox
    Screen('Preference', 'SkipSyncTests', 2);
    Priority(2);
    
    % Clear the workspace and the screen
    sca;
    close all;
    
    % Here we call some default settings for setting up Psychtoolbox
    PsychDefaultSetup(2);
    
    % Get the screen numbers
    internal.screens = Screen('Screens');

    screenNum=max(internal.screens);
    
    % Define black and white
    internal.white = WhiteIndex(screenNum);
    internal.black = BlackIndex(screenNum);
    
    % Open an on screen window
    [internal.window_main, internal.windowRect] = PsychImaging('OpenWindow', screenNum, internal.black);
    
    % Get the size of the on screen window
    [internal.screenXpixels, internal.screenYpixels] = Screen('WindowSize', internal.window_main);
    
    %get size of the screen
    [internal.width, internal.height]=Screen('DisplaySize',  screenNum);
    
    % set up a monitoring window
    internal.window_monitor=PsychImaging('OpenWindow', 1, internal.black,internal.windowRect/4);
    
    % Get the centre coordinate of the window
    [internal.xCenter, internal.yCenter] = RectCenter(internal.windowRect);

    % make the first trial run
    internal.runtrial=1;
end