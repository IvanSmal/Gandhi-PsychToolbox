function [e,in]=sound_task(e,in)
persistent deviceWriter sineGenerator counter TLength
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~in.trialstarted
    counter = 0;
    deviceWriter = audioDeviceWriter;
    deviceWriter.SupportVariableSizeInput=1;
    sineGenerator = audioOscillator;
    sineGenerator.SamplesPerFrame=500;

    TLength = 5;
    e.trial.insert('intervals',TLength);

    e.trial.insert('UserDefined',deviceWriter,sineGenerator);

    % start the trial and label the first state
    in.trialstarted = 1;
    in.setstate('Start');
end

%%
%check for a condition to start the first active 'state' of the tiral
if in.checkint('Sound_On',TLength)
    counter = counter+1;
    sineGenerator.Frequency=1000+counter;
    sine = sineGenerator();
    deviceWriter(sine);

elseif in.checkstate('Sound_On') %set conditions for continuing

    in.setstate('stop')
    in.trialstarted = 0;
    in.runtrial = 0;
    release(deviceWriter)
    clear deviceWriter sineGenerator counter
end

end