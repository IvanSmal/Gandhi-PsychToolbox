function [mh]=TimingCheck(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    T0=mh.gettarg('T0'); % grab T0

    % set the intervals for the trial
    T0_reach=mh.getint('T0_reach');
    T0_hold=mh.getint('T0_hold');

    % start the trial and label the first state
    mh.starttrial
    mh.setstate('State1');
end

%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('State1')
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','getpos'));  % Draw the texture to the screen
    
    if mh.checkint('State1','T0_reach')  && ~mh.checkeye('T0')
        % just chill
    elseif ~mh.checkeye('T0')
        mh.setstate('State2');
    else
        mh.setstate('State2');
    end
    mh.endstate;
end
%%
if mh.checkstate('State2')
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','getpos'));  % Draw the texture to the screen
    
    if mh.checkint('State2','T0_reach')  && ~mh.checkeye('T0')
        % just chill
    elseif ~mh.checkeye('T0')
        mh.setstate('State3');
    else
        mh.setstate('State3');
    end
    mh.endstate;
end
%%
if mh.checkstate('State3')
    mh.Screen('FillOval', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','getpos'));  % Draw the texture to the screen
    
    if mh.checkint('State3','T0_reach')  && ~mh.checkeye('T0')
        % just chill
    elseif ~mh.checkeye('T0')
        mh.stoptrial(0);
    else
        mh.stoptrial(1);
    end
    mh.endstate;
end
end
