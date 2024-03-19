function mh = rewcheck(mh,app,forcestop)
if nargin == 2
    forcestop = 0;
end
%reward button check
[~,~,events]=xippmex('digin');
if ~isempty(events)
    if sum([events.sma4])>1 && ~mh.rew.rewon
        mh.reward(app.RewardDuration.Value);
    end
end
%reward gui check
if app.RewardButton.Value
    if ~mh.rew.rewon
        mh.reward(app.RewardDuration.Value);
        app.RewardButton.Value=1;
    else
        app.RewardButton.Value=0;
    end
end

if mh.rew.rewon==1 && isnumeric(mh.rew.int)
    duration = mh.rew.int;
elseif mh.rew.rewon == 1
    duration = mh.rew.int.duration;
end

if mh.rew.rewon==1 &&...
        getsecs<mh.rew.rewstart+duration &&...
        ~app.StopRewardButton.Value

    xippmex('digout',3,1);

elseif (mh.rew.rewon==1 &&...
        getsecs>(mh.rew.rewstart+duration+0.025)) || forcestop || app.StopRewardButton.Value %the 0.25 is a calibration adjustment
    xippmex('digout',3,0);
    app.insToTxtbox(['reward t: ' num2str(getsecs-mh.rew.rewstart) 's']);
    mh.rew.rewon=0;
    app.StopRewardButton.Value = 0;
    app.RewardButton.Value=0;
    clear sound
end
[~,~,~]=xippmex('digin'); %clear digital buffer
end