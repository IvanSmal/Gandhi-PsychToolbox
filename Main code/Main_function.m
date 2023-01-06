function [inter,e]=Main_function(app,varargin)
% internal assign
if nargin<2
    inter=internal;
end

inter.app=app;

addpath(genpath(fileparts(which('Main_function'))));                        % add subfolders with all functions
rmpath(what('DEBUG').path) % remove DEBUG code override
xippath=genpath(fileparts(which('xippmex')));

d=data;                                                                     %initialize the data structure with class 'data'
%% DEBUG??
debug=1;
if debug
    inter.app.insToTxtbox('!!!RUNNING IN DEBUG MODE!!! YOU MIGHT (WILL) LOSE YOUR XIPPMEX PATH')

    rmpath(xippath)
    addpath(what('DEBUG').path)
end
%% set up daq. Modify the specifics in the setupDAQ function
dq = setupDAQ(app);

%% set all the PsychToolbox and daq parameters in setupPsychToolbox function

if ~exist('w','var')                                                        %check whether the window is not already set up
    inter=setupPsychToolbox(inter);
    inter.diode_pos=[0,inter.screenYpixels-50,50,inter.screenYpixels];
end
%% make parameters if none are in workspace
ise = evalin( 'base', 'exist(''e'',''var'') == 1' );                        %check if data is in workspace

if ise
    e=evalin('base','e');                                           %if data from an interrupted session exists, continue working on it
else
    e=makeparams(inter);                                                    %initialize a new experiment structure with class 'experiment'
end

%% Calibrate eye voltage
inter.eye=eyeinfo(app); % init eye

if get(app.RuncalibrationCheckBox,'Value')  
    inter.eye = inter.eye.eyeCalib(inter);
end

%% call trial types
set(app.STOPButton,'Enable','on')
app.FinalizeButton.Enable = 'off';

while ~app.STOPButton.Value
    % check for calibration change
    inter.trial.tstarttime=getsecs;
    inter.trialnumpersistent = inter.trialnumpersistent+1;
    inter.trial.trialnum=inter.trialnumpersistent;
    inter.app.insToTxtbox(['trial number', num2str(inter.trial.trialnum)])
    
    if dq; xippmex('trial', 'recording'); end %start trellis
 %% ******** trial in this loop ********   
    while inter.runtrial==1 && ~app.STOPButton.Value
        tic
        [e,inter]=bareMinimum(e,inter);
        
        Screen2('Flip',inter,[],[],2);

        if app.RewardButton.Value
            inter.reward(e.getint('reward'))
            app.RewardButton.Value=0;
        end

        inter.rewcheck;
        drawnow
        toc
    end
    inter.trial.tstoptime=getsecs;

    while (inter.trial.tstoptime+e.intervals.iti.getint)>getsecs %% ITI
        Screen2('Flip',inter);
        drawnow
    end
%% post-trial
    
    inter.runtrial=1; % activate next trial
    
    if inter.diode_on==1 % incase diode was on at the end, turn it off
        inter.diodeflip
        Screen2('Flip',inter,[],[],2);
    end 

    ttime=(inter.trial.tstoptime-inter.trial.tstarttime)*1000;

    d.eyepos=inter.eye.geteye(ttime);
    d.neural_data='placeholder';
    d.eyesync=xippmex('cont',10241,ttime,'1ksps');
    inter.trial.data=d;

    e.trial(inter.trial.trialnum)=inter.trial;
    disp(inter.trial.trialnum)
    xippmex('trial', 'stopped'); 

    inter.trial=trial; 
end
%% ending procedure

app.savestate(inter,e)

set(app.STOPButton,'enable','off')

set(app.STOPButton,'Value',0)
app.FinalizeButton.Enable = 'on';
end
