function dq=setupDAQ(app)
c=0;
dq = xippmex;
while xippmex == 0
    insToTxtbox(app, 'could not connect to the DAQ. Retrying')
    pause(5)
    c=c+1;
    if c==3
        a=questdlg('could not connect to DAQ. Proceeding without a functioning daq will cause unexpected errors',...
            'DAQ error',...
            'continue','quit','quit');
        if strcmp(a,'continue')
            insToTxtbox(app, 'Continuing without a DAQ. Errors WILL occur')
        else
            set(app.STOPButton,'Value',0)
        end
        return
    end
end

% initialize all the channels

end