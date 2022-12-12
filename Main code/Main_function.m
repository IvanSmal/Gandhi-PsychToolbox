function [inter,e]=Main_function(app,inter,e)
addpath(genpath(fileparts(which('Main_function'))));                        % add subfolders with all functions
rmpath(what('DEBUG').path) % remove DEBUG code override
xippath=genpath(fileparts(which('xippmex')));

d=data;                                                                     %initialize the data structure with class 'data'
%% DEBUG??
debug=1;
if debug
    insToTxtbox(app, '!!!RUNNING IN DEBUG MODE!!! YOU MIGHT (WILL) LOSE YOUR XIPPMEX PATH')

    rmpath(xippath)
    addpath(what('DEBUG').path)
end
%% set up daq. Modify the specifics in the setupDAQ function
dq = setupDAQ(app);

%% get cpu times in seconds to sync trellis to matlab
time.matlab=getsecs;
time.trellis=xippmex('time')/30000/60;

%% set all the PsychToolbox and daq parameters in setupPsychToolbox function
% internal assign
inter=internal;
if ~exist('w','var')                                                        %check whether the window is not already set up
    inter=setupPsychToolbox(inter);
end
%% make parameters if none are in workspace
ise = evalin( 'base', 'exist(''e'',''var'') == 1' );                        %check if data is in workspace

if ise
    e=evalin('base','e');                                           %if data from an interrupted session exists, continue working on it
else
    e=makeparams(app,inter);                                                    %initialize a new experiment structure with class 'experiment'
end

%% Calibrate eye voltage
inter.eye=eyeinfo(app); % init eye

if get(app.RuncalibrationCheckBox,'Value')  
    inter.eye = eyeCalib(inter.eye,inter,app);
end

%% call trial types
set(app.STOPButton,'Enable','on')
app.FinalizeButton.Enable = 'off';

while ~app.STOPButton.Value
    % check for calibration change
    inter.trial.tstarttime=getsecs;
    inter.trial.trialnum=inter.trial.trialnum+1;
    insToTxtbox(app,['trial number', num2str(inter.trial.trialnum)])
    
    if dq; xippmex('trial', 'recording'); end %start trellis
 %% ******** trial in this loop ********   
    while inter.runtrial==1 && ~app.STOPButton.Value
        tic
%         internal.eye=eye(app); 
        [e,inter]=bareMinimum(e,inter);
        
        Screen2('Flip',inter);

%         if app.RewardButton.Value
%             inter.reward(inter,e.getint('reward'))
%             app.RewardButton.Value=0;
%         end

        inter.rewcheck(app);
        drawnow
        toc
    end
    inter.trial.tstoptime=getsecs;

    while (inter.trial.tstoptime+e.intervals.iti.getint)>getsecs %% ITI
        Screen2('Flip',inter);
    end
%% post-trial
    
    inter.runtrial=1; % activate next trial

    diode(inter,e,1); % incase diode was on at the end, turn it of for a frame

    e.intervals.iti.getint

    ttime=(getsecs-inter.trial.tstarttime)*1000;
    if dq 
        allDAQdata=inter.eye.geteye(ttime);
        d.eyepos=allDAQdata;
        d.neural_data='placeholder';
        d.eyesync=allDAQdata(:,end);
        e.trial(inter.trial.trialnum).data=d;
        xippmex('trial', 'stopped'); 
    end 
end
%% ending procedure

savestate(e)

set(app.STOPButton,'enable','off')

set(app.STOPButton,'Value',0)
app.FinalizeButton.Enable = 'on';
end
