function [mh]=MovingTargInward(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    T0=mh.gettarg('T0'); % grab T0
    T1_Moving_in=mh.gettarg('T1_Moving_in');

    % set the intervals for the trial
    T0_reach=mh.getint('T0_Reach');
    T0_hold=mh.getint('T0_Hold');
    delay=mh.getint('delay');
    T1_reach=mh.getint('T1_Reach');
    T1_hold=mh.getint('T1_Hold');

    % start the trial and label the first state
    mh.starttrial
    mh.setstate('T0_reach_state');
end

%% T0_REACH
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('T0_reach_state')

    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','getpos'));
    % mh.plotwindow('T0',mh.trialtarg('T0','getpos'));

    if mh.checkint('T0_reach_state','T0_Reach')  && ~mh.checkeye('T0')
        % just chill
    elseif ~mh.checkeye('T0')
        mh.stoptrial(0);
    else
        mh.setstate('T0_hold_state');
    end
    mh.endstate;
end

%% T0_HOLD
if mh.checkstate('T0_hold_state')
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor'),mh.trialtarg('T0','getpos'));
    % mh.plotwindow('T0',mh.trialtarg('T0','getpos'));

    if mh.checkint('T0_hold_state','T0_Hold') && mh.checkeye('T0')
        % just chill
    elseif ~mh.checkeye('T0')
        mh.stoptrial(0);
    else %set conditions for continuing
        mh.setstate('delay_state');
    end
    mh.endstate;
end
%% delay
if mh.checkstate('delay_state')

    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','getpos'));
    mh.Screen('FillOval', mh, mh.trialtarg('T1_Moving_in','getcolor'),mh.trialtarg('T1_Moving_in','getpos'));
    % mh.plotwindow('T0',mh.trialtarg('T0','getpos'));
    % mh.plotwindow('T1_Moving_in',mh.trialtarg('T1_Moving_in','getpos'));

    if mh.checkint('delay_state','delay') && mh.checkeye('T0')
        % just chill
    elseif mh.checkint('delay_state','delay') && ~mh.checkeye('T0')
        mh.stoptrial(0);
    elseif ~mh.checkint('delay_state','delay')
        mh.setstate('T1_reach_state_moving');
    end
    mh.endstate;
end
%% T1_REACH_MOVING
if mh.checkstate('T1_reach_state_moving')
    targpos=mh.trialtarg('T1_Moving_in','getpos','continue','delay_state');
    mh.Screen('FillOval', mh, mh.trialtarg('T1_Moving_in','getcolor'),targpos);
    % mh.plotwindow('T1_Moving_in',targpos);

    if mh.checkint('T1_reach_state_moving','T1_Reach') && ~mh.checkeye('T1_Moving_in',targpos)
        % just chill
    elseif ~mh.checkeye('T1_Moving_in',targpos)
        mh.stoptrial(0);
    elseif mh.checkint('T1_reach_state_moving','T1_Reach') && mh.checkeye('T1_Moving_in',targpos)
        mh.setstate('T1_hold_state_moving');
    end
    mh.endstate;
end
%% T1_HOLD_MOVING
if mh.checkstate('T1_hold_state_moving')
    targpos=mh.trialtarg('T1_Moving_in','getpos','continue','delay_state');
    mh.Screen('FillOval', mh, mh.trialtarg('T1_Moving_in','getcolor'),targpos);
    % mh.plotwindow('T1_Moving_in',targpos);

    if mh.checkint('T1_hold_state_moving','T1_Hold') && mh.checkeye('T1_Moving_in',targpos)
        % just chill
    elseif ~mh.checkeye('T1_Moving_in',targpos)
        mh.stoptrial(0);
    else %set conditions for continuing
        mh.reward(mh.getint('reward'));
        mh.stoptrial(1);
    end
    mh.endstate;
end

end
