function stoptrial(mh,success)
mh.setstate('stop_autogenerated')

for i=1:50
    % mh.evalgraphics('gr.trialstarted=0;');
    mh.Screen('FillOval', 'windowPtr', [0 0 0],[8000 8000 8050 8050]);
    mh.Screen('sendtogr')
    % writeline(mh.graphicsport,'trialend','0.0.0.0',2023);
    pause(0.001)
end

flush(mh.graphicsport);
mh.graphicssent=1;
mh.trialstarted = 0;
mh.runtrial = 0;
mh.trial.success=success;
if success
    mh.sum_success=mh.sum_success+1;
    mh.repeatfailed=0;
    mh.repeatfailedcounter=0;
else
    mh.repeatfailed=1;
    mh.repeatfailedcounter=mh.repeatfailedcounter+1;
end
end