function [mh]=Pong_straightDown(mh)
% set the trial parameters once per trial. this makes sure you dont set
% them every screen flip
if ~mh.trialstarted

    ball=mh.gettarg('ball'); % grab T0
    paddle=mh.gettarg('paddle'); %grab T1

    % set the intervals for the trial
    maxtime=mh.getint('maxtime');

    %starting direction (1==down)
    direction=1;

    % PUT EVERYTHING INTO OUTGOING TRIAL DATA
    mh.trial.insert('targets',ball,paddle);
    mh.trial.insert('intervals',maxtime);
    mh.trial.insert('UserDefined',direction)

    % start the trial and label the first state
    mh.trialstarted = 1;
    mh.setstate('balldown_initial');

    clear ball paddle
end
%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('balldown_initial')
    ballpos=mh.trialtarg('ball','getpos');
    paddlepos=mh.trialtarg('paddle','getpos');

    if ballpos(4)<paddlepos(2)

        Screen2('FillRect',...
            mh, mh.trialtarg('paddle','getcolor'),...
            mh.trialtarg('paddle','getpos'));

        Screen2('FillOval',...
            mh, mh.trialtarg('ball','getcolor'),...
            mh.trialtarg('ball','getpos'));

    elseif mh.targcollisioncheck('ball','paddle')
        mh.trial.targets.ball.position=mh.trial.targets.ball.final_position;
        mh.trial.targets.ball.direction=90;
        mh.setstate('ballup')
    else
        mh.stoptrial(1)
    end
end
%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('ballup')

    ballpos=mh.trialtarg('ball','getpos');
    paddlepos=mh.trialtarg('paddle','getpos');

    if ballpos(4)>10

        Screen2('FillRect',...
            mh, mh.trialtarg('paddle','getcolor'),...
            mh.trialtarg('paddle','getpos'));

        Screen2('FillOval',...
            mh, mh.trialtarg('ball','getcolor'),...
            mh.trialtarg('ball','getpos','balldown'));

    else
        mh.trial.targets.ball.position=mh.trial.targets.ball.final_position;
        mh.trial.targets.ball.direction=-90;
        mh.setstate('balldown')
    end
end
%%
%check for a condition to start the first active 'state' of the tiral
if mh.checkstate('balldown')

    ballpos=mh.trialtarg('ball','getpos');
    paddlepos=mh.trialtarg('paddle','getpos');

    if ballpos(4)<paddlepos(2)

        Screen2('FillRect',...
            mh, mh.trialtarg('paddle','getcolor'),...
            mh.trialtarg('paddle','getpos'));

        Screen2('FillOval',...
            mh, mh.trialtarg('ball','getcolor'),...
            mh.trialtarg('ball','getpos'));

    elseif mh.targcollisioncheck('ball','paddle')
        mh.trial.targets.ball.position=mh.trial.targets.ball.final_position;
        mh.trial.targets.ball.direction=90;
        mh.setstate('ballup')
    else
        mh.stoptrial(1)
    end
end
