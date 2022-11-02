function [d,w]=center_out(e,w,dq)
%% center out
d=trial; %initialte all data
statecount=0; %reset statecount

s=GetSecs; %get start trial time

w=diode(w,e,statecount);
setstate(d,'start',GetSecs-s); %set state

% Make our random Targ1 coordinates
T0=e.targets.T0; % grab center
T1=e.targets.T1; % grab T1
T1.position=T1.randpos; %single out one random position
setd(d,'targets',T0,T1) % set targets into structure

% set our intervals if randomized
T0_reach=e.intervals.T0_reach;
T0_hold=e.intervals.T0_hold;
setd(d,'intervals',T0,T1) % set targets into structure

xeye=1;
yeye=1;
%% START TARGET
statecount=statecount+1;
setstate(d,'T0_show',GetSecs-s);
tp=GetSecs;
w=diode(w,e,statecount);

while GetSecs<(tp+T0_reach.getint)
    % get eye position
    [xeye, yeye]=eyepos(w,dq,xeye,yeye);
    
    if ~hitdetect([xeye,yeye],T0.squarepos,T0.twindow)

        % Draw the rect to the screen
        Screen('FillRect', w.window_main,T0.color , T0.squarepos);

        % Flip to the screen
        Screen('Flip', w.window_main);
        cont=0;
    else
        cont=1;
        break
    end
end

%% START TARGET HOLD
setstate(d,'T0_hold',GetSecs-s);
tp=GetSecs;
statecount=statecount+1;
w=diode(w,e,statecount);

while GetSecs<tp+T0_hold.getint
    % get eye position
    [xeye, yeye]=eyepos(w,dq,xeye,yeye);

    if hitdetect([xeye,yeye],T0.squarepos,T0.twindow)

        % Draw the rect to the screen
        Screen('FillRect', w.window_main,T0.color , T0.squarepos);

        % Flip to the screen
        Screen('Flip', w.window_main);
        cont=0;
    else
        cont=1;
        break
    end
end

%% TARG 1
if cont
setstate(d,'T0_hold',GetSecs-s);
tp=GetSecs;
statecount=statecount+1;
w=diode(w,e,statecount);

while GetSecs<tp+T0_hold.getint
    % get eye position
    [xeye, yeye]=eyepos(w,dq,xeye,yeye);

    if hitdetect([xeye,yeye],T1.squarepos,T1.twindow)

        % Draw the rect to the screen
        Screen('FillRect', w.window_main,T1.color , T1.squarepos);

        % Flip to the screen
        Screen('Flip', w.window_main);
        cont=0;
    else
        cont=1;
        break
    end
end
end
%% TARG 1 HOLD
if cont
setstate(d,'T0_hold',GetSecs-s);
tp=GetSecs;
statecount=statecount+1;
w=diode(w,e,statecount);

while GetSecs<tp+T0_hold.getint
    % get eye position
    [xeye, yeye]=eyepos(w,dq,xeye,yeye);

    if hitdetect([xeye,yeye],T1.squarepos,T1.twindow)

        % Draw the rect to the screen
        Screen('FillRect', w.window_main,T1.color , T1.squarepos);

        % Flip to the screen
        Screen('Flip', w.window_main);
        success=1;
    else
        success=0;
        break
    end
end
else
    success=0;
end
%% END

d.success=success;
clear mpos

end
