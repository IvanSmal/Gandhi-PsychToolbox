function mh = rewcheck(mh,app,forcestop)
if nargin == 2
    forcestop = 0;
end
%reward button check
% [~,~,events]=xippmex('digin');
% if ~isempty(events)
%     if sum([events.sma4])>1 && ~mh.rew.rewon
%         mh.reward(app.RewardDuration.Value,1);
%     end
% end
% %reward gui check
if app.RewardButton.Value
    mh.reward(app.RewardDuration.Value,1);
    app.RewardButton.Value=0;
end

% stop-reward gui check: close the reward valve (SMA out 3) right now. This is
% what the reward handler's own hardware stop does, and it takes effect even
% mid-reward instead of waiting for the handler's duration loop to finish.
% Then tell the reward handler, so it ends its duration loop and reports (and
% counts toward Total reward / the trial's reward) only the time the valve was
% actually open, not the full requested duration.
if app.StopRewardButton.Value
    try, xippmex('digout', 3, 0); catch, end
    try, writeline(mh.rewardport, "stop", '0.0.0.0', 2026); catch, end % RewardHandler's stop port
    app.StopRewardButton.Value=0;
end

% [~,~,~]=xippmex('digin'); %clear digital buffer
end