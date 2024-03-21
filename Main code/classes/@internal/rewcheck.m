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
    disp('here')
    mh.reward(app.RewardDuration.Value);
    app.RewardButton.Value=0;
end

[~,~,~]=xippmex('digin'); %clear digital buffer
end