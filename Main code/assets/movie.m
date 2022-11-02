function [data,w]=movie(params,w)
%% center out
% Flip outside of the loop to get a time stamp
vbl = Screen('Flip', w.window_main);

% display random targets around the center

statecount=0; %reset statecount

s=GetSecs; %get start trial time

d_col=diodecolor(statecount);
Screen('FillRect', w.window_main, d_col, params.diode);

params.trial=params.trial+1; %count the trial

Screen('Flip', w.window_main); %flash diode for start trial
data(params.trial).state.START=GetSecs-s; %record some info

midx=0; %get mouse loop index

% Make our random Targ1 coordinates

targ1(:, 1) = CenterRectOnPointd(params.baseRect,...
    w.xCenter+params.addX(randi(length(params.addX))),...
    w.yCenter+params.addY(randi(length(params.addY))));

success=1; % assume success until failure



%% START TARGET
tp=GetSecs;
statecount=statecount+1;
d_col=diodecolor(statecount);
Screen('PlayMovie', params.movie, 0.1,1);

while GetSecs<tp+params.waitsecs
    tex = Screen('GetMovieImage', w.window_main, params.movie); %get movie frame

        if tex<=0
            Screen('PlayMovie', params.movie, 1);
        end

    data(params.trial).state.T0=GetSecs-s; %record some info

    %log mouse movement
    midx=midx+1;
    [mpos(1,midx), mpos(2,midx), mpos(3,midx)]=mousepos(w.window_main,s);

    % get cursor position
    [xmouse, ymouse]=mousepos(w.window_main,s);

    if ~hitdetect([xmouse,ymouse],params.targ0) && ~KbCheck
        % Draw the rect to the screen
        Screen('DrawTexture', w.window_main, tex);
        Screen('FillRect', w.window_main, [params.allColors]', params.targ0);
        Screen('FillRect', w.window_main, d_col, params.diode);
        Screen('DrawDots', w.window_main, [xmouse ymouse], 10, w.white, [], 2);
        
        % Flip to the screen
        vbl=Screen('Flip', w.window_main);
        cont=0;
    else
        cont=1;
        break
    end
    Screen('PlayMovie', params.movie, 0);
end

% TARG 1
if cont
    statecount=statecount+1;
    d_col=diodecolor(statecount);

    tp=GetSecs;
    while GetSecs< tp+params.waitsecs

        data(params.trial).state.T1=GetSecs-s; %record some info

        %log mouse movement
        midx=midx+1;
        [mpos(1,midx), mpos(2,midx), mpos(3,midx)]=mousepos(w.window_main,s);

        % get cursor position
        [xmouse, ymouse] = GetMouse(w.window_main);
        xmouse = min(xmouse, w.screenXpixels);
        ymouse = min(ymouse, w.screenYpixels);

        if ~hitdetect([xmouse,ymouse],targ1) && ~KbCheck
            % Draw the rect to the screen
            Screen('FillRect', w.window_main, [params.allColors]', targ1);
            Screen('FillRect', w.window_main, d_col, params.diode);
            Screen('DrawDots', w.window_main, [xmouse ymouse], 10, w.white, [], 2);

            % Flip to the screen
            vbl=Screen('Flip', w.window_main);
            success=0;
        else
            success=1;
            break
        end
    end
else
    success=0;
end

% ITI
tp=GetSecs;
statecount=statecount+1;
d_col=diodecolor(statecount);

while GetSecs< tp+params.iti

    data(params.trial).state.ITI=GetSecs-s; %record some info

    %log mouse movement
    midx=midx+1;
    [mpos(1,midx), mpos(2,midx), mpos(3,midx)]=mousepos(w.window_main,s);

    Screen('WindowSize', w.window_main)
    Screen('FillRect', w.window_main, d_col, params.diode);

    vbl=Screen('Flip', w.window_main);
end

Screen('FillRect', w.window_main, [0;0;0], params.diode);
Screen('Flip', w.window_main); % incase diode was on at the end, turn it of for a frame

data(params.trial).mousepos=mpos;
data(params.trial).success=success;
clear mpos
data(params.trial).state.END=GetSecs-s;

end
%% extra functions
function out=hitdetect(cursor,target)
if cursor(1)>=target(1) && cursor(2) >= target(2) &&...
        cursor(1)<target(3) && cursor(2)< target(4)
    out=1;
else
    out=0;
end
end

function [xmouse, ymouse, t]=mousepos(window,s)
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

[xmouse, ymouse] = GetMouse(window);
xmouse = min(xmouse, screenXpixels);
ymouse = min(ymouse, screenYpixels);

t=GetSecs-s;
end

function d_col=diodecolor(statecount)
if rem(statecount,2)
    d_col=[1;1;1];
else
    d_col=[0;0;0];
end
end