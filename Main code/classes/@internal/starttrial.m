function starttrial(mh)
mh.trialstarted = 1;
mh.setstate('start_autogenerated')
mh.evalgraphics('gr.trialstarted=1;');
mh.trial.tstarttime=getsecs;

mh.autocalibrationmatrix_buffer = mh.autocalibrationmatrix;
xippmex('digout', 4, 1)
for i=1:200
    mh.evalgraphics(['gr.activestatename =' '''' mh.activestatename '''' ';gr.flipped=0;'])
    mh.Screen('sendtogr')
    pause(0.001)
end

xippmex('digout', 4, 0);
[~,~,events]=xippmex('digin');
end