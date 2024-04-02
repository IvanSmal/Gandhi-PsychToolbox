function stoptrial(mh,success)
mh.setstate('stop')
mh.trialstarted = 0;
mh.runtrial = 0;
mh.trial.success=success;
if success
    mh.sum_success=mh.sum_success+1;
end
mh.evalgraphics('gr.trialstarted=0;');
end