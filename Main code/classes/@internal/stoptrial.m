function stoptrial(mh,success)
mh.setstate('stop_autogenerated')

for i=1:50
    mh.evalgraphics(['gr.activestatename =' '''' mh.activestatename '''' ';gr.flipped=0;'])
    mh.Screen('sendtogr')
    pause(0.001)
end

flush(mh.graphicsport);
mh.graphicssent=1;
mh.trialstarted = 0;
mh.runtrial = 0;
mh.trial.success=success;
if success
    mh.sum_success=mh.sum_success+1;
end
mh.Screen('sendtogr')
for i=1:100
    mh.evalgraphics('gr.trialstarted=0;');
    writeline(mh.graphicsport,'trialend','0.0.0.0',2023);
    pause(0.0001)
end
end