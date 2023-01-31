function [mh]=bareMinimum(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    T0=mh.targets.T0; % grab T0
    T1=mh.targets.T1; %grab T1
    T1.position=T1.randpos+T0.position;    

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
if mh.checkint('T0_reach','T0_reach')
    % Draw the rect to the screen
    Screen2('FillRect', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','squarepos'));
elseif mh.checkstate('T0_reach') %set conditions for continuing
    mh.setstate('T0_hold');
end
%%
if mh.checkint('T0_hold','T0_hold')

    Screen2('FillRect', mh, mh.trialtarg('T0','getcolor') , mh.trialtarg('T0','squarepos'));

elseif mh.checkstate('T0_hold')%set conditions for continuing
    mh.setstate('T1_reach')
end
%%
if mh.checkint('T1_reach','T1_reach')

    Screen2('FillRect', mh, mh.trialtarg('T1','getcolor') , mh.trialtarg('T1','squarepos'));

elseif mh.checkstate('T1_reach') %set conditions for continuing
    mh.setstate('T1_hold')
end
%%
if mh.checkint('T1_hold','T1_hold')

    Screen2('FillRect', mh, mh.trialtarg('T1','getcolor') , mh.trialtarg('T1','squarepos'));

elseif mh.checkstate('T1_hold') %set conditions for ending
    mh.setstate('stop')
    mh.trialstarted = 0;
    mh.runtrial = 0;

end

end