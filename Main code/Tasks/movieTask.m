function [mh]=movieTask(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted
    moviepath=fullfile(pwd, 'assets', 'movie2.mp4');
    mh.movie=Screen2('OpenMovie',mh.window_main,moviepath);

    T1=mh.gettarg('T1_moving'); %grab T1

    % set the intervals for the trial
    T0_reach=mh.getint('T0_reach');

    mh.trial.insert('intervals',T0_reach);
    mh.trial.insert('targets',T1);

    % start the trial and label the first state
    mh.trialstarted = 1;
    mh.setstate('T0_reach');

    Screen2('PlayMovie',mh.movie,1)
end

%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('T0_reach')
    if mh.checkint('T0_reach','T0_reach') %&& ~mh.checkeye('T0')
        tex = Screen2('GetMovieImage', mh.window_main, mh.movie);
        Screen2('DrawTexture', mh, tex,[],mh.windowRect)
        Screen2('FillRect', mh, mh.trialtarg('T1','getcolor') , mh.trialtarg('T1','getpos'));
    else
        mh.stoptrial(1);
        Screen2('CloseMovie')
        Screen2('close')
    end
end

end