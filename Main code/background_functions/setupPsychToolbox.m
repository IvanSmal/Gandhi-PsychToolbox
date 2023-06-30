function mh=setupPsychToolbox(mh)
   
    Screen('Preference', 'SkipSyncTests', 2);
    Priority(2);
    
    % set experimental environment
    setenv('PSYCH_EXPERIMENTAL_NETWMTS', '1');
    
    % Clear the workspace and the screen
    sca;
    close all;

    % Here we call some default settings for setting up Psychtoolbox
    PsychDefaultSetup(2);
    
    % Get the screen numbers
    mh.screens = Screen('Screens');
    
    if max(mh.screens) == 0
        errordlg('Only found 1 screen')
        er=1;
        return
    else
        screenNum=max(mh.screens);
    end
    
    % Define black and white
    black = BlackIndex(screenNum);
    
    % Open an on screen window
    
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer')
    PsychImaging('AddTask', 'General', 'FloatingPoint16Bit')
    % PsychImaging('AddTask', 'General',...
    %     'MirrorDisplayTo2ndOutputHead',...
    %     0 , monitor_rect);%, specialFlags=0][, useOverlay=0]);

    [mh.window_main, mh.windowRect] = PsychImaging('OpenWindow', screenNum, black);
    

    % Get the size of the on screen window
    [mh.screenXpixels, mh.screenYpixels] = Screen('WindowSize', mh.window_main);
    
    %get size of the screen
    [mh.width, mh.height]=Screen('DisplaySize',  screenNum);
%%
    
    % set up a monitoring window
    monitor_rect=floor(mh.windowRect/4);

    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
    PsychImaging('AddTask', 'General', 'UsePanelFitter', [mh.screenXpixels, mh.screenYpixels], 'Full')
    % PsychImaging('AddTask', 'General', 'FloatingPoint16Bit')
    [mh.window_monitor, mh.monitor_rect]=PsychImaging('OpenWindow', 0, black,monitor_rect,[],[],[],[],[],kPsychGUIWindow);
    
    % Get the centre coordinate of the window
    [mh.xCenter, mh.yCenter] = RectCenter(mh.windowRect);


    % make the first trial run
    mh.diode_pos=[0,mh.screenYpixels-50,50,mh.screenYpixels];

end