function [eyeMin, eyeMax] = calibrate(w,dq)
    start(dq, 'continuous') % start data collection

    TargPos=[0 0 20 20;
        w.screenXpixels/2-10 0 w.screenXpixels/2+10 20;
        w.screenXpixels-20 0 w.screenXpixels 20;
        w.screenXpixels-20 w.screenYpixels/2-10 w.screenXpixels w.screenYpixels/2+10;
        w.screenXpixels-20 w.screenYpixels-20 w.screenXpixels w.screenYpixels;
        w.screenXpixels/2-10 w.screenYpixels-20 w.screenXpixels/2+10 w.screenYpixels;
        0 w.screenYpixels-20 20 w.screenYpixels;
        0 w.screenYpixels/2-10 20 w.screenYpixels/2+10];

    for i=1:size(TargPos,1)
        Screen('FillRect', w.window_main, [1 1 1], TargPos(i,:));
        Screen('Flip', w.window_main);
        pause(0.2)
    end

    allvals=read(dq,'all','OutputFormat','Matrix');

    eyeMin=-min(allvals,[],'all');
    eyeMax=-max(allvals,[],'all');

    stop(dq)
end