function daqStatus=setupDAQ(app)
retryCount=0;
daqStatus = xippmex;
app.XippmexLamp.Color=[0,1,0];
while daqStatus == 0
    daqStatus = xippmex;
    app.XippmexLamp.Color=[1,0,0];
    insToTxtbox(app, 'could not connect to the DAQ. Retrying')
    pause(5)
    retryCount=retryCount+1;
    if retryCount==3
        answer=questdlg('could not connect to DAQ. Proceeding without a functioning daq will cause unexpected errors',...
            'DAQ error',...
            'continue','quit','quit');
        if strcmp(answer,'continue')
            insToTxtbox(app, 'Continuing without a DAQ. Errors WILL occur')
        else
            set(app.STOPButton,'Value',0)
        end
        return
    end
end

% initialize all the channels

end
