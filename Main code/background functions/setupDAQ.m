function dq=setupDAQ
    daqreset % just to be sure
    devlist=daqlist;
    if isempty(devlist)
        insToTxtbox(app,'no DAQ device detected.')
        return
    else
        dq=daq('ni');
        addinput(dq,devlist.DeviceID,"ai0","Voltage")
        addinput(dq,devlist.DeviceID,"ai1","Voltage")

        addinput(dq,devlist.DeviceID,"ai7","Voltage") %reserve last analog in for photodiode

        dq.Rate=1000;
    end
end