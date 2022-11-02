function w=setupPsychToolbox
    Screen('Preference', 'SkipSyncTests', 2);
    Priority(2);
    
    % Clear the workspace and the screen
    sca;
    close all;
    
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

    % Retreive the maximum priority number and set max priority
    topPriorityLevel = MaxPriority(w.window_main);
    Priority(topPriorityLevel); 
    
    % Get the size of the on screen window
    [w.screenXpixels, w.screenYpixels] = Screen('WindowSize', w.window_main);
    
    %get size of the screen
    [w.width, w.height]=Screen('DisplaySize',  w.screenNumber);
    
    % set up a monitoring window
    w.window_monitor=PsychImaging('OpenWindow', 1, w.black,w.windowRect/4);
    
    % Get the centre coordinate of the window
    [w.xCenter, w.yCenter] = RectCenter(w.windowRect);
end