function [mh]=JustT0(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    T0=mh.gettarg('T0'); % grab T0;
    % set the intervals for the trial
    T0_reach=mh.getint('T0_reach');
    T0_hold=mh.getint('T0_hold');

    % start the trial and label the first state
    mh.starttrial
    mh.setstate('T0_reach');
end

%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('T0_reach')
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','getpos'));  % Draw the texture to the screen
    % mh.plotwindow('T0')

    if mh.checkint('T0_reach','T0_reach')  && ~mh.checkeye('T0')
        % just chill
    elseif ~mh.checkeye('T0')
        mh.stoptrial(0);
    else
        mh.setstate('T0_hold');
    end
    mh.endstate;
end
%%
if mh.checkstate('T0_hold')
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor'),mh.trialtarg('T0','getpos','continue'));
    
    if mh.checkint('T0_hold','T0_hold') && mh.checkeye('T0')
       % just chill
    elseif ~mh.checkeye('T0')
        mh.stoptrial(0);
    else %set conditions for continuing
        mh.stoptrial(1);
        mh.reward(mh.getint('reward'));
    end
    mh.endstate;
end

end
