classdef graphics < handle
    %GRAPHICS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fliprequest = 0;
        screens
        window_main
        window_monitor
        windowRect
        monitor_rect
        original_monitor_params;
        winparams;
        newsize;
        circleadder=10;
        newsize_true;
        left_right=0;
        fontsize=30;
        up_down=0;
        screenXpixels
        screenYpixels
        width
        height
        xCenter
        yCenter
        xlines
        ylines
        scalefactor = 1;
        monitortexture
        toconvert
        pixelsforlines
        monitormovieplaceholder
        movie
        texture
        diode_pos
        eye
        flipped = 0;
        activestatename='null';
        user_defined
        target
        movieplaying=0;
        diode_color=[0 0 0];
        functionsbuffer=[];
        trialstarted=0;
        lastarg;
        gridlinesmatrix;
        eyehistory;
        fliptimes;
        commandIDs;
        commid_udp;
        state_history={'null'};
        center_circle=[0 0 0 0];
    end
end