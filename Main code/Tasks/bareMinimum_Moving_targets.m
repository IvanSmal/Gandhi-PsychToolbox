function [mh]=bareMinimum_Moving_targets(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    T0=mh.gettarg('T0_moving'); % grab T0
    T1=mh.gettarg('T1_moving'); %grab T1

    % set the intervals for the trial
    T0_reach=mh.getint('T0_reach');
    T0_hold=mh.getint('T0_hold');
    T1_reach=mh.getint('T1_reach');
    T1_hold=mh.getint('T0_hold');
    TestString=num2str(T0_reach);

    % PUT EVERYTHING INTO OUTGOING TRIAL DATA
    mh.trial.insert('targets',T0,T1);
    mh.trial.insert('intervals',T0_reach,T0_hold,T1_reach,T1_hold);
    mh.trial.insert('UserDefined',TestString);

    % start the trial and label the first state
    mh.trialstarted = 1;
    mh.setstate('T0_reach');

    clear T0 T1 T0_reach T0_hold T1_reach T1_hold
end

%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('T0_reach')
    if mh.checkint('T0_reach','T0_reach')  && ~mh.checkeye('T0')
        Screen2('DrawTexture', mh, mh.!gi('T0','gettexture') ,[], mh.trialtarg('T0','getpos'));  % Draw the texture to the screen
    elseif ~mh.checkeye('T0')
        mh.stoptrial(0)
    else
        mh.setstate('T0_hold');
    end
end
%%
if mh.checkstate('T0_hold') && mh.checkeye('T0')
    if mh.checkint('T0_hold','T0_hold')
        Screen2('FillOval', mh, mh.trialtarg('T0','getcolor'),mh.trialtarg('T0','getpos','continue'));
    elseif mh.checkstate('T0_hold') && ~mh.checkeye('T0')
        mh.stoptrial(0)
    else %set conditions for continuing
        mh.setstate('T1_reach')
    end
end
%%
if mh.checkstate('T1_reach')
    if mh.checkint('T1_reach','T1_reach')

        Screen2('FillRect', mh, mh.trialtarg('T1','getcolor') , mh.trialtarg('T1','getpos'));

    else %set conditions for continuing
        mh.setstate('T1_hold')
    end
end

%%
if mh.checkstate('T1_hold')
    if mh.checkint('T1_hold','T1_hold')

        Screen2('FillRect', mh, mh.trialtarg('T1','getcolor') , mh.trialtarg('T1','getpos','T1_reach'));

    else %set conditions for ending
        mh.stoptrial(1);
    end
end

end