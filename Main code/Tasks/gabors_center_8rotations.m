function [data,w]=gabors_center_8rotations(params,w,dq)
%% housekeeping
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

success=1; % assume success until failure

xeye=1;
yeye=1;
%% Actual trial parameter stuff 
% Make our random gabor orientations
GabProp = [params.gabor.phase, params.gabor.freq, params.gabor.sigma,...
    params.gabor.contrast, params.gabor.aspectRatio, 0, 0, 0]; % set up athe properties of the gabor

rot=params.gabor.orientation(randi(size(params.gabor.orientation,2))); % get the random orientation

%% START TARGET
statename='Gabor_1';
tp=GetSecs;
statecount=statecount+1;
d_col=diodecolor(statecount);

mon=parfeval(backgroundPool,@monitor,1,w,params,xeye,yeye);

while GetSecs<tp+params.T0_waitsecs

    data(params.trial).state.(statename)=GetSecs-s; %record some info

    % get cursor position

    [xeye, yeye]=eyepos(w,dq,xeye,yeye);

    if ~hitdetect([xeye,yeye],params.targ0,params.twindow) && ~KbCheck

        % Draw the gabor to the screen
        Screen('DrawTexture', w.window_main, params.gabor.GabTex,...
            [], [], rot, [], [], [], [],...
            kPsychDontDoRotation, GabProp');

        Screen('FillRect', w.window_main, d_col, params.diode); %DO NOT FORGET THE DIODE

        % Flip to the screen
        vbl=Screen('Flip', w.window_main);
        
        % monitor
        monitor(w,params,xeye,yeye);

        success=0;
    else
        success=1;
        break
    end
end
%% END

data(params.trial).success=success;
clear mpos
data(params.trial).state.END=GetSecs-s;

end
