function [in,er]=setupPsychToolbox(in)
    er=0;
    
    Screen('Preference', 'SkipSyncTests', 2);
    Priority(2);
    
    % Clear the workspace and the screen
    sca;
    close all;
    
    % Here we call some default settings for setting up Psychtoolbox
    PsychDefaultSetup(2);
    
    % Get the screen numbers
    in.screens = Screen('Screens');
    
    if max(in.screens) == 0
        errordlg('Only found 1 screen')
        er=1;
        return
    else
        screenNum=max(in.screens);
    end
    
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
    [in.window_monitor, in.monitor_rect]=PsychImaging('OpenWindow', 0, black,in.windowRect/4+100, [],[],[],[],[],kPsychGUIWindow);
    
    % Get the centre coordinate of the window
    [in.xCenter, in.yCenter] = RectCenter(in.windowRect);

    % make the first trial run
    in.runtrial=1;

end