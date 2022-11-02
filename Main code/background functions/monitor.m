function monitor(w,params,xeye,yeye)
%% grab main window image THIS STEP IS SLOW MAYBE I'LL FIND ANOTHER SOLUTION
imageArray=Screen('GetImage', w.window_main,[],'frontBuffer');

Screen('PutImage', w.window_monitor, imageArray, w.windowRect/4) % trying this incase this is faster than creating a texture first
%% trying copyWindow command

Screen('CopyWindow',w.window_main,w.window_monitor,)
%% draw eye

    Screen('DrawDots', w.window_monitor, [xeye/4 yeye/4], 10, w.white, [], 2);

%% display some other stuff
    Screen('TextSize', w.window_monitor, 12);
    Screen('TextFont', w.window_monitor, 'Courier');
    DrawFormattedText( w.window_monitor, ['trial: ' num2str(params.trialnum)], 10, 50, w.white);

%% flip
    Screen('Flip', w.window_monitor);

end