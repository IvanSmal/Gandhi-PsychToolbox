classdef graphics < handle
    %GRAPHICS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        screens
        window_main
        window_monitor
        windowRect
        monitor_rect
        screenXpixels
        screenYpixels
        width
        height
        xCenter
        yCenter
        monitortexture
        monitormovieplaceholder
        movie
        texture
        diode_pos
        eye
        flipped
        activestatename
        user_defined
        target
        movieplaying=0
        diode_color=[0 0 0];
        newgraphics=0;
    end
end

