function stoptrial(mh,success)
mh.setstate('stop')
mh.trialstarted = 0;
mh.runtrial = 0;
mh.trial.success=success;
mh.evalgraphics('gr.trialstarted=0;');
end