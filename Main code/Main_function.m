function [inter,e]=Main_function(app,varargin)
%% initialize filepaths for xippmex and debug mode etc
addpath(genpath(fileparts(which('Main_function'))));                        % add subfolders with all functions
rmpath(what('DEBUG').path) % remove DEBUG code override
xippath=genpath(fileparts(which('xippmex')));

%% set all the parameters up

if nargin==1
    inter=internal;
    inter.app=app; %stick app in there so less stuff to path
    inter=setupPsychToolbox(inter);
    inter.diode_pos=[0,inter.screenYpixels-50,50,inter.screenYpixels];
    e=makeparams(inter);   
elseif nargin == 2
    if isa(varargin{1},'experiment')
        e=varargin{1};
        e.trial=trial; %clear old data
        inter=internal;
        inter.app=app; %stick app in there so less stuff to path
        inter=setupPsychToolbox(inter);
        inter.diode_pos=[0,inter.screenYpixels-50,50,inter.screenYpixels];
    else
        inter=varargin{1};
        inter.app=app;
        e=makeparams(inter); 
    end
elseif nargin ==3
    inter=varargin{1};
    inter.app=app;
    e=varargin{2};
end

%% DEBUG??
debug=1;
if debug
    inter.app.insToTxtbox('!!!RUNNING IN DEBUG MODE!!! YOU MIGHT (WILL) LOSE YOUR XIPPMEX PATH')

    rmpath(xippath)
    addpath(what('DEBUG').path)
end
%% set up daq. Modify the specifics in the setupDAQ function
dq = setupDAQ(app);

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
    d=data;   %initialize empty data
    d.eyepos=inter.eye.geteye(ttime);
    d.neural_data='placeholder';
    d.eyesync=xippmex('cont',10241,ttime,'1ksps');
    inter.trial.data=d;

    e.trial(inter.trial.trialnum)=inter.trial;
    xippmex('trial', 'stopped'); 

    inter.trial=trial; 
end
%% ending procedure
inter.app=[];

e.System_Properties=inter;

app.savestate(inter,e)

set(app.STOPButton,'enable','off')

set(app.STOPButton,'Value',0)
app.FinalizeButton.Enable = 'on';
end
