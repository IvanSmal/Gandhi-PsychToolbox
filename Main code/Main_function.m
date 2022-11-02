function [w,e]=Main_function(app,w,e)
% example of experiment script
addpath(genpath(fileparts(which('Main_function'))));                        % add subfolders with all functions

d=data;                                                                     %initialize the data structure with class 'data'
%% set up daq. Modify the specifics in the setupDAQ function
dq=setupDAQ;
%% set all the PsychToolbox and daq parameters in setupPsychToolbox function
if ~exist('w','var')                                                        %check whether the window is not already set up
    w=setupPsychToolbox;
end
%% make parameters if none are in workspace
ise = evalin( 'base', 'exist(''e'',''var'') == 1' );                        %check if data is in workspace

if ise
    e=evalin('base','e');                                           %if data from an interrupted session exists, continue working on it
else
    e=makeparams(app,w);                                                    %initialize a new experiment structure with class 'experiment'
end

%% Calibrate eye voltage

if get(app.RuncalibrationCheckBox,'Value')
    [w.minEye, w.maxEye]=calibrate(w,dq);
end

if ~exist('w','var') || ~isfield(w,'minEye')
    insToTxtbox(app,'calibration likely not complete. please calibrate eye position first')
    return
end

%% call trial types
set(app.STOPButton,'Enable','on')
app.FinalizeButton.Enable = 'off';


while ~app.STOPButton.Value
    e.trialnum=e.trialnum+1;
    insToTxtbox(app,['trial number', num2str(e.trialnum)])
    start(dq, 'continuous') % start data collection

    r=1;
        if r==1
            [e.trial(e.trialnum),w]=center_out(e,w,dq);
        elseif r==2
            % another task
        elseif r==3
            % another task
        end

    w=diode(w,e,1); % incase diode was on at the end, turn it of for a frame

    e.intervals.iti.waitint %wait ITI
    allDAQdata=read(dq,'all','OutputFormat','Matrix');
    d.eyepos=allDAQdata(:,1:2);
    d.neural_data='placeholder';
    d.eyesync=allDAQdata(:,end);
    e.trial(e.trialnum).data=d;
    stop(dq)
end
%% ending procedure

savestate(e)

set(app.STOPButton,'enable','off')

set(app.STOPButton,'Value',0)
app.FinalizeButton.Enable = 'on';
end
