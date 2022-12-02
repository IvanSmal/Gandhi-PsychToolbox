function [internal,e]=Main_function(app,internal,e)
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
time.matlab=cputime;
time.trellis=xippmex('time')/30000/60;

%% set all the PsychToolbox and daq parameters in setupPsychToolbox function
if ~exist('w','var')                                                        %check whether the window is not already set up
    internal=setupPsychToolbox;
end
%% make parameters if none are in workspace
ise = evalin( 'base', 'exist(''e'',''var'') == 1' );                        %check if data is in workspace

if ise
    e=evalin('base','e');                                           %if data from an interrupted session exists, continue working on it
else
    e=makeparams(app,internal);                                                    %initialize a new experiment structure with class 'experiment'
end

%% Calibrate eye voltage
internal.eye=eye(app); % init eye

if get(app.RuncalibrationCheckBox,'Value')  
    internal.eye = eyeCalib(internal.eye,internal,app);
end

%% call trial types
set(app.STOPButton,'Enable','on')
app.FinalizeButton.Enable = 'off';

while ~app.STOPButton.Value
    internal.eye=eye(app); % check for calibration change
    internal.tstarttime=cputime;
    e.trialnum=e.trialnum+1;
    insToTxtbox(app,['trial number', num2str(e.trialnum)])
    if dq; xippmex('trial', 'recording'); end %start trellis

    r=1; % logic for if you want to mix trial types
    while internal.runtrial==1
        if r==1
            [e,internal]=bareMinimum(e,internal);
        elseif r==2
            % another task
        elseif r==3
            % another task
        end
        Screen2('Flip',internal)
    end
    
    internal.runtrial=1; % activate next trial

    internal=diode(internal,e,1); % incase diode was on at the end, turn it of for a frame

    e.intervals.iti.waitint %wait ITI
    ttime=(cputime-internal.tstarttime)*1000;
    if dq 
    allDAQdata=internal.eye.geteye(ttime);
    d.eyepos=allDAQdata;
    d.neural_data='placeholder';
    d.eyesync=allDAQdata(:,end);
    e.trial(e.trialnum).data=d;
    xippmex('trial', 'stopped'); 
    end 
end
%% ending procedure

savestate(e)

set(app.STOPButton,'enable','off')

set(app.STOPButton,'Value',0)
app.FinalizeButton.Enable = 'on';
end
