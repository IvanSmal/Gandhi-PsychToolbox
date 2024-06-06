function out=checkeye(mh,targ,pos)
% if ~exist('pos','var') || isempty(pos)
    if isempty(mh.trial.targets.(targ).moving_position)
        targpos=mh.trialtarg(targ,'getpos','center');
    elseif numel(mh.trial.targets.(targ).moving_position(:,1))==1
        targpos=deg2pix(mh.trial.targets.(targ).moving_position(end,:),'cart',mh.screenparams);
    else
        tbackwards=abs(mh.trial.targets.(targ).timestamp-mh.trial.targets.(targ).timestamp(end));
        firstidx=find(tbackwards<(mh.trailing_window_time/1000),1);
        targpos=deg2pix(mh.trial.targets.(targ).moving_position(firstidx:10:end,:),'cart',mh.screenparams);
    end
% else
%     disp('here')
%     centerx=(pos(3)+pos(1))/2;
%     centery=(pos(4)+pos(2))/2;
%     targpos=[centerx centery];
% end

%% add gain to window
%"gain" might be an incorrect term here. Essentially, the gain value
%determines how many extra degrees to add to the window based on how
%eccentric the target is. So at gain "0.1", 0.1 degrees will be added to
%the window per 1 degree of eccentricity. The window will not be multiplied
%by 1.1
degreesfromcenter=pix2deg(targpos,'cart',mh.screenparams);
targfromcenter=hypot(degreesfromcenter(end,1),degreesfromcenter(end,2));
truegainvalue=targfromcenter*mh.eccentricity_gain;
truegainpixels=deg2pix([truegainvalue truegainvalue],'size',mh.screenparams); % pixels to add to window

windowsize_all=deg2pix([mh.trial.targets.(targ).window mh.trial.targets.(targ).window],'size',mh.screenparams);
radius=windowsize_all(3)+truegainpixels(3); %using index 3 because assumes a perfect circle so x and y values are the same. so 3 and 4 should be the same.
howfareye=targpos-mh.eye.geteye;
hypoteye=hypot(howfareye(:,1),howfareye(:,2));

mh.checkeye_counter(end)=any(radius>hypoteye);
mh.checkeye_counter=circshift(mh.checkeye_counter,-1);
out=floor(mean(mh.checkeye_counter));

if out==1 && mh.trial.targets.(targ).speed == 0
    whereseye=mh.eye.getraweye;
    if isempty(mh.autocalibrationmatrix_buffer)
        mh.autocalibrationmatrix_buffer(1)=targpos(1);
        mh.autocalibrationmatrix_buffer(2)=whereseye(1);
        mh.autocalibrationmatrix_buffer(3)=targpos(2);
        mh.autocalibrationmatrix_buffer(4)=whereseye(2);
    else
        idx=size(mh.autocalibrationmatrix,1)+1;
        mh.autocalibrationmatrix_buffer(idx,1)=targpos(1);
        mh.autocalibrationmatrix_buffer(idx,2)=whereseye(1);
        mh.autocalibrationmatrix_buffer(idx,3)=targpos(2);
        mh.autocalibrationmatrix_buffer(idx,4)=whereseye(2);
    end
    [~,uidx]=unique(mh.autocalibrationmatrix_buffer(:,[1,3]),'last','rows');
    mh.autocalibrationmatrix_buffer=mh.autocalibrationmatrix_buffer(uidx,:);
end

centerx=targpos(:,1);
centery=targpos(:,2);
squarepos=round([centerx-radius centery-radius centerx+radius centery+radius]);
for i=1:size(centerx,1)
    color(size(centerx,1)-i+1,:)=[1 0 0];
end
mh.Screen('FrameOval','monitoronly',color',squarepos');
end