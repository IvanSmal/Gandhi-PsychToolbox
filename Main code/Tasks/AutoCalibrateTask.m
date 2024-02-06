function [mh]=AutoCalibrateTask(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted
    T0=mh.gettarg('T_Calibrate'); % grab T0

    % set the intervals for the trial
    T0_reach=mh.getint('T0_Reach');
    T0_hold=mh.getint('T0_Hold');

    % start the trial and label the first state
    mh.starttrial
    mh.setstate('T0_reach_state');
end

%% T0_REACH
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('T0_reach_state')
    
    mh.Screen('FillOval', mh, mh.trialtarg('T_Calibrate','getcolor'),mh.trialtarg('T_Calibrate','getpos'));  

    if mh.checkint('T0_reach_state','T0_Reach')  && ~mh.checkeye('T_Calibrate')
        % just chill
    elseif ~mh.checkeye('T_Calibrate')
        mh.stoptrial(0);
    else
        mh.setstate('T0_hold_state');
        
    end
    mh.endstate;
end

%% T0_HOLD
if mh.checkstate('T0_hold_state')
    mh.Screen('FillOval', mh, mh.trialtarg('T_Calibrate','getcolor'),mh.trialtarg('T_Calibrate','getpos'));

    if mh.checkint('T0_hold_state','T0_Hold') && mh.checkeye('T_Calibrate')
       % just chill
    elseif ~mh.checkeye('T_Calibrate')
        mh.stoptrial(0);
    else %set conditions for continuing
        mh.reward(mh.getint('reward'))
        mh.stoptrial(1);
    end
    mh.endstate;
end
end
