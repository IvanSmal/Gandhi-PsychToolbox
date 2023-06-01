function [mh]=Pong_angles(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    ball2=mh.gettarg('ball2'); % grab T0
    paddle=mh.gettarg('paddle'); %grab T1

    %walls here
    l_wall=mh.gettarg('l_wall');
    r_wall=mh.gettarg('r_wall');
    t_wall=mh.gettarg('t_wall');
    failwall=mh.gettarg('failwall');

    % set the intervals for the trial
    maxtime=mh.getint('maxtime');

    %starting direction (1==down)
    bouncecheck=0;

    % PUT EVERYTHING INTO OUTGOING TRIAL DATA
    mh.trial.insert('targets',ball2,paddle,l_wall,r_wall,t_wall,failwall);
    mh.trial.insert('intervals',maxtime);
    mh.trial.insert('UserDefined',bouncecheck)

    % start the trial and label the first state
    mh.trialstarted = 1;
    mh.setstate('bounce');

    clear ball2 paddle
end
%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('bounce')
    if mh.checkint('bounce','maxtime')

        Screen2('FillRect',...
            mh, mh.trialtarg('paddle','getcolor'),...
            mh.trialtarg('paddle','getpos'));

        Screen2('FillOval',...
            mh, mh.trialtarg('ball2','getcolor'),...
            mh.trialtarg('ball2','getpos'));

        %draw walls
        Screen2('FillRect',...
            mh, mh.trialtarg('l_wall','getcolor'),...
            mh.trialtarg('l_wall','getpos'));

        Screen2('FillRect',...
            mh, mh.trialtarg('r_wall','getcolor'),...
            mh.trialtarg('r_wall','getpos'));

        Screen2('FillRect',...
            mh, mh.trialtarg('t_wall','getcolor'),...
            mh.trialtarg('t_wall','getpos'));

        if mh.targcollisioncheck('ball2','l_wall') || mh.targcollisioncheck('ball2','r_wall')
            mh.trial.targets.ball2.position=mh.trial.targets.ball2.final_position;
            initdir=mh.trial.targets.ball2.direction;
            mh.trial.targets.ball2.direction=180-initdir;
            mh.setstate('bounce')
        elseif mh.targcollisioncheck('ball2','t_wall')
            mh.trial.targets.ball2.position=mh.trial.targets.ball2.final_position;
            initdir=mh.trial.targets.ball2.direction;
            mh.trial.targets.ball2.direction=90+(90-(initdir-180));
            mh.setstate('bounce')
        elseif mh.targcollisioncheck('ball2','paddle')
            mh.trial.UserDefined.bouncecheck=mh.trial.UserDefined.bouncecheck+1;

            mh.trial.targets.ball2.position=mh.trial.targets.ball2.final_position;
            initdir=mh.trial.targets.ball2.direction;
            mh.trial.targets.ball2.direction=90+(90-(initdir-180));
            mh.setstate('bounce')
        elseif mh.targcollisioncheck('ball2','failwall')
            mh.trial.targets.ball2.position=mh.trial.targets.ball2.final_position;
            initdir=mh.trial.targets.ball2.direction;
            mh.trial.targets.ball2.direction=90+(90-(initdir-180));
            mh.stoptrial(0)
        end
        if mh.trial.UserDefined.bouncecheck == 3
            mh.stoptrial(1)
        end
    else
        mh.stoptrial(0)
    end
end


