function starttrial(mh)
mh.trialstarted = 1;
mh.setstate('start_autogenerated')
mh.trial.tstarttime=mh.trial.state.start_autogenerated.time;

mh.autocalibrationmatrix_buffer = mh.autocalibrationmatrix;
xippmex('digout', 4, 1)
justonce=0;
for i=1:50
    mh.Screen('FillOval', 'windowPtr', [0 0 0],[8000 8000 8050 8050]);
    justonce=justonce+1;
    % mh.evalgraphics(['gr.activestatename =' '''' mh.activestatename '''' ';gr.flipped=0;'])
    % writeline(mh.graphicsport,'trialstart','0.0.0.0',2023);
    mh.Screen('sendtogr')
    if justonce==1;
    mh.makesound('sine',850,1,0.3);
    end
    pause(0.001)
end

xippmex('digout', 4, 0);
% [~,~,events]=xippmex('digin');
mh.stimmed=0;
end