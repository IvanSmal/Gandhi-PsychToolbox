function out=checkcursor(mh,targ,idx)
%CHECKCURSOR Is cursor `idx` inside target `targ`? Cursor analogue of checkeye.
%   idx selects mh.cursors{idx} (a cursorinfo). Same window logic as checkeye,
%   including the mm-target rule (fixed millimetre window, no eccentricity
%   expansion). No eye autocalibration -- that is eye-specific. The window is
%   drawn on the monitor in a distinct colour so eye and cursor windows are
%   distinguishable when both are shown.
if nargin < 3 || isempty(idx), idx = 1; end
mvtype='cart'; if strcmpi(mh.trial.targets.(targ).degreestype,'mm'), mvtype='mm'; end

if isempty(mh.trial.targets.(targ).moving_position)
    targpos=mh.trialtarg(targ,'getpos','center');
elseif numel(mh.trial.targets.(targ).moving_position(:,1))==1
    targpos=deg2pix(mh.trial.targets.(targ).moving_position,mvtype,mh.screenparams);
else
    tbackwards=abs(mh.trial.targets.(targ).timestamp-mh.trial.targets.(targ).timestamp(end));
    firstidx=find(tbackwards<(mh.trailing_window_time/1000),1);
    targpos=deg2pix(mh.trial.targets.(targ).moving_position(firstidx:10:end,:),mvtype,mh.screenparams);
end

%% window (same rule as checkeye; mm targets get a fixed millimetre window)
if strcmpi(mh.trial.targets.(targ).degreestype,'mm')
    truegainpixels=[0 0 0 0];
    windowsize_all=deg2pix([mh.trial.targets.(targ).window mh.trial.targets.(targ).window],'mmsize',mh.screenparams);
else
    degreesfromcenter=pix2deg(targpos,'cart',mh.screenparams);
    targfromcenter=hypot(degreesfromcenter(end,1),degreesfromcenter(end,2));
    truegainvalue=targfromcenter*mh.eccentricity_gain;
    truegainpixels=deg2pix([truegainvalue truegainvalue],'size',mh.screenparams);
    windowsize_all=deg2pix([mh.trial.targets.(targ).window mh.trial.targets.(targ).window],'size',mh.screenparams);
end
radius=windowsize_all(3)+truegainpixels(3);

% self-provision the cursor from its ini assignment on first use, so a task
% only has to call checkcursor(mh,targ,idx) -- no startup wiring needed.
if numel(mh.cursors) < idx || isempty(mh.cursors{idx})
    mh.cursors{idx} = cursorinfo(idx);
end
cpos=mh.cursors{idx}.getcursor;
howfar=targpos-cpos;
hypocur=hypot(howfar(:,1),howfar(:,2));

% per-cursor grace counter (3-sample window), self-initialising
if numel(mh.checkcursor_counter) < idx || isempty(mh.checkcursor_counter{idx})
    mh.checkcursor_counter{idx}=[0,0,0];
end
ctr=mh.checkcursor_counter{idx};
ctr(end)=any(radius>hypocur);
ctr=circshift(ctr,-1);
mh.checkcursor_counter{idx}=ctr;
out=floor(mean(ctr));

%% draw the cursor window on the monitor (blue-ish, vs the eye's dark red)
centerx=targpos(:,1);
centery=targpos(:,2);
squarepos=round([centerx-radius centery-radius centerx+radius centery+radius]);
color=[0 0 0.6;0 0 0.6];
mh.Screen('FrameOval','monitoronly',color',squarepos([1,end],:)',5);
end
