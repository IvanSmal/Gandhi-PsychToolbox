function Test_function(app)
%% gui test function
params.trialnum=0;
set(app.STOPButton,'Enable','on')
while ~app.STOPButton.Value
    pause(0.5)
    
    params.trialnum=params.trialnum+1;
    aa=params.trialnum;

    set(app.ParametersTextArea,'Value',num2str(aa));
end
stpstr=sprintf('%s\n%s',string(get(app.ParametersTextArea,'Value'))...
    , 'now stopping please wait');
set(app.ParametersTextArea,'Value',stpstr);
set(app.STOPButton,'enable','off')
pause(3)
set(app.STOPButton,'Value',0)
end