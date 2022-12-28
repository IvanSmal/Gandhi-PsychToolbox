function [e,in]=bareMinimum(e,in)
persistent T0 T1 T0_reach T0_hold T1_reach T1_hold
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~in.trialstarted
    
    T0=e.targets.T0; % grab T0
    T1=e.targets.T1; %grab T1
    T1.position=T1.randpos+T0.position;    

    % set the intervals for the trial
    T0_reach=e.getint('T0_reach');
    T0_hold=e.getint('T0_hold');
    T1_reach=e.getint('T1_reach');
    T1_hold=e.getint('T0_hold');

    % PUT EVERYTHING INTO OUTGOING TRIAL DATA
    e.trial.insert('targets',T0,T1);
    e.trial.insert('intervals',T0_reach,T0_hold,T1_reach,T1_hold);

    % start the trial and label the first state
    in.trialstarted = 1;
    in.setstate('T0_reach');
end

%%
%check for a condition to start the first active 'state' of the tiral
if in.checkint('T0_reach',T0_reach)
    % Draw the rect to the screen
    Screen2('FillRect', in, T0.color , T0.squarepos);
elseif in.checkstate('T0_reach') %set conditions for continuing

    in.setstate('T0_hold');
end
%%
if in.checkint('T0_hold',T0_hold)

    Screen2('FillRect', in, T0.color , T0.squarepos);

elseif in.checkstate('T0_hold')%set conditions for continuing
    in.setstate('T1_reach')
end
%%
if in.checkint('T1_reach',T1_reach)

    Screen2('FillRect', in, T1.color , T1.squarepos);

elseif in.checkstate('T1_reach') %set conditions for continuing
    in.setstate('T1_hold')
end
%%
if in.checkint('T1_hold',T1_hold)

    Screen2('FillRect', in, T1.color , T1.squarepos);

elseif in.checkstate('T1_hold') %set conditions for ending
    in.setstate('stop')
    in.trialstarted = 0;
    in.runtrial = 0;
    clear T0 T1 T0_reach T0_hold T1_reach T1_hold
end

end