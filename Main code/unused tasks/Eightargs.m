function [mh]=Eightargs(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    T1=mh.gettarg('T1'); % grab T1
    % set the intervals for the trial
    T1_reach=mh.getint('T1_reach');
    T1_hold=mh.getint('T1_hold');

    % start the trial and label the first state
    mh.starttrial
    mh.setstate('T1_reach');
end

%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('T1_reach')
    mh.Screen('FillOval', mh, mh.trialtarg('T1','getcolor') , mh.trialtarg('T1','getpos'));  % Draw the texture to the screen
    
    if mh.checkint('T1_reach','T1_reach')  && ~mh.checkeye('T1')
        % just chill
    elseif ~mh.checkeye('T1')
        mh.stoptrial(0);
    else
        mh.setstate('T1_hold');
    end
    mh.endstate;
end
%%
if mh.checkstate('T1_hold')
    mh.Screen('FillOval', mh, mh.trialtarg('T1','getcolor'),mh.trialtarg('T1','getpos','continue'));
    
    if mh.checkint('T1_hold','T1_hold') && mh.checkeye('T1')
       % just chill
    elseif ~mh.checkeye('T1')
        mh.stoptrial(0);
    else %set conditions for continuing
        mh.stoptrial(1);
        mh.reward(mh.getint('reward'));
    end
    mh.endstate;
end

end
