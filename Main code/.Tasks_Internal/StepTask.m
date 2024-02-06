function [mh]=StepTask(mh)
% randdur=randi([1,length(mh.trial.intervals.delay.duration)]);
% mh.trial.intervals.delay.duration=mh.trial.intervals.delay.duration(randdur)



% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted
    % display('int')
    T0=mh.gettarg('T0'); % grab T0
    T_Calibrate=mh.gettarg('T_Calibrate');

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
    
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor'),mh.trialtarg('T0','getpos'));  

    if mh.checkint('T0_reach_state','T0_Reach')  && ~mh.checkeye('T0')
        % just chill
    elseif ~mh.checkint('T0_reach_state','T0_Reach') && ~mh.checkeye('T0')
        mh.stoptrial(0);
    elseif mh.checkeye('T0')
        mh.setstate('T0_hold_state');        
    end
    mh.endstate;
end

%% T0_HOLD
if mh.checkstate('T0_hold_state')
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor'),mh.trialtarg('T0','getpos'));

    if mh.checkint('T0_hold_state','T0_Hold') && mh.checkeye('T0')
       % just chill
    elseif ~mh.checkeye('T0')
        mh.stoptrial(0);
    else %set conditions for continuing
        mh.setstate('T1_reach_state_stationary');
    end
    mh.endstate;
end
%% T1_REACH_STATIONARY
if mh.checkstate('T1_reach_state_stationary')
    mh.Screen('FillOval', mh, mh.trialtarg('T_Calibrate','getcolor'),mh.trialtarg('T_Calibrate','getpos'));

    if mh.checkint('T1_reach_state_stationary','T1_Reach') && ~mh.checkeye('T_Calibrate')

    elseif ~mh.checkeye('T_Calibrate')

        mh.stoptrial(0);
    elseif mh.checkeye('T_Calibrate')
        mh.setstate('T1_hold_state_stationary');
    end
    mh.endstate;
end
%% T1_HOLD_STATIONARY
if mh.checkstate('T1_hold_state_stationary')
    mh.Screen('FillOval', mh, mh.trialtarg('T_Calibrate','getcolor'),mh.trialtarg('T_Calibrate','getpos'));

    if mh.checkint('T1_hold_state_stationary','T1_Hold') && mh.checkeye('T_Calibrate')
       % just chill
    elseif mh.checkint('T1_hold_state_stationary','T1_Hold') && ~mh.checkeye('T_Calibrate')
        mh.stoptrial(0);
    elseif ~mh.checkint('T1_hold_state_stationary','T1_Hold') && mh.checkeye('T_Calibrate')
        mh.reward(mh.getint('reward'));
        mh.stoptrial(1);
    end
    mh.endstate;
end

end
