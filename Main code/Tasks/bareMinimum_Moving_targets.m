function [mh]=bareMinimum_Moving_targets(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    mh.gettarg('T0_moving'); % grab T0
    mh.gettarg('T1_moving'); %grab T1

    % set the intervals for the trial
    mh.getint('T0_reach');
    mh.getint('T0_hold');
    mh.getint('T1_reach');
    mh.getint('T1_hold');

    % start the trial and label the first state
    mh.starttrial
    mh.setstate('T0_reach');
end

%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('T0_reach')
    mh.Screen('FillOval', mh, mh.trialtarg('T0_moving','getcolor'),mh.trialtarg('T0_moving','getpos'));
    if mh.checkint('T0_reach','T0_reach')  && ~mh.checkeye('T0_moving')
        %just chill
    elseif ~mh.checkeye('T0_moving')
        mh.stoptrial(0)
    else
        mh.setstate('T0_hold');
    end
    mh.endstate;
end
%%
if mh.checkstate('T0_hold') && mh.checkeye('T0_moving')
    mh.Screen('FillOval', mh, mh.trialtarg('T0_moving','getcolor'),mh.trialtarg('T0_moving','getpos','continue'));
    if mh.checkint('T0_hold','T0_hold')
        
    elseif mh.checkstate('T0_hold') && ~mh.checkeye('T0_moving')
        mh.stoptrial(0)
    else %set conditions for continuing
        mh.setstate('T1_reach')
    end
    mh.endstate;
end
%%
if mh.checkstate('T1_reach')
    mh.Screen('FillRect', mh, mh.trialtarg('T1_moving','getcolor') , mh.trialtarg('T1_moving','getpos'));
    if mh.checkint('T1_reach','T1_reach')

    else %set conditions for continuing
        mh.setstate('T1_hold')
    end
    mh.endstate;
end

%%
if mh.checkstate('T1_hold')
    mh.Screen('FillRect', mh, mh.trialtarg('T1_moving','getcolor') , mh.trialtarg('T1_moving','getpos','T1_reach'));
    if mh.checkint('T1_hold','T1_hold')

    else %set conditions for ending
        mh.stoptrial(1);
    end
    mh.endstate;
end

end