function [out] = d2pc(rx,ry,w, dist,targtype,size)
%     defaultTarg='circle';
%     defaultSqsize=20;
%     defaultDist=1000;
%     
%     p = inputParser;
%     addRequired(p,'rx');
%     addRequired(p,'ry');
%     
%     ddOptional(p,'w');
% 
%     addParameter(p,'dist',defaultDist,@isnumeric);
%     addParameter(p,'targtype',defaultTarg,@isstring);
%     addParameter(p,'size',defaultSqsize,@isnumeric);

    if ~exist('dist','var')
        dist=1000; %default distance 1M
    end
    
    if ~exist('targtype','var')
        targtype='circle'; %default distance 1M
    end

    if ~exist('w','var')
        PsychDefaultSetup(2);
    
        % Get the screen numbers
        w.screens = Screen('Screens');
        
        % Draw to the external screen if avaliable
        w.screenNumber = max(w.screens);
    
        % Open an on screen window
        [w.window_main, w.windowRect] = PsychImaging('OpenWindow', w.screenNumber);
        
        % Get the size of the on screen window
        [w.screenXpixels, w.screenYpixels] = Screen('WindowSize', w.window_main);
        [w.width, w.height]=Screen('DisplaySize',  w.screenNumber);
        
        % Close window
        Screen('close',w.window_main)
    end

    pxW=w.width/w.screenXpixels;
    pxH=w.height/w.screenYpixels;

    pxMidX=floor(w.screenXpixels/2);
    pxMixY=floor(w.screenYpixels/2);

    desiredXdist=tand(rx)*dist;
    desiredYdist=tand(ry)*dist;

    px(1)=pxMidX+desiredXdist/pxW;
    px(2)=pxMixY+desiredYdist/pxH;

if strcmp(targtype,'circle')
    out=px;
end

if strcmp(targtype,'square')
    if ~exist('size','var')
        size=40;
        disp('used default size of 40px')
    end

    size=size/2;

    sqpx(1)=px(1)-size;
    sqpx(2)=px(2)-size;
    sqpx(3)=px(1)+size;
    sqpx(4)=px(2)+size;

    out=sqpx;
end
end
    
