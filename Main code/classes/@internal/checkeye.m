function out=checkeye(mh,targ,pos)
if ~exist('pos','var') || isempty(pos)
    targpos=mh.trialtarg(targ,'getpos','center');
    targposSquare=mh.trialtarg(targ,'getpos');
else
    targetlocation = pos;
    centerx=(targetlocation(3)+targetlocation(1))/2;
    centery=(targetlocation(4)+targetlocation(2))/2;
    targpos=[centerx centery];
    targposSquare=pos;
end

degreesfromcenter=pix2deg(targpos,'cart',mh.screenparams);
targfromcenter=hypot(degreesfromcenter(1),degreesfromcenter(2));
truegainvalue=targfromcenter*mh.eccentricity_gain;
truegainpixels=deg2pix([truegainvalue truegainvalue],'size',mh.screenparams);

windowsize_all=deg2pix([mh.trial.targets.(targ).window mh.trial.targets.(targ).window],'size',mh.screenparams);
radius=windowsize_all(3)+truegainpixels(3);
howfareye=targpos-mh.eye.geteye;
hypoteye=hypot(howfareye(1),howfareye(2));

mh.checkeye_counter(end)=radius>hypoteye;
mh.checkeye_counter=circshift(mh.checkeye_counter,-1);
out=floor(mean(mh.checkeye_counter));

if out==1
    whereseye=mh.eye.getraweye;
    if isempty(mh.autocalibrationmatrix)
        mh.autocalibrationmatrix(1)=targpos(1);
        mh.autocalibrationmatrix(2)=whereseye(1);
        mh.autocalibrationmatrix(3)=targpos(2);
        mh.autocalibrationmatrix(4)=whereseye(2);
    else
        idx=size(mh.autocalibrationmatrix,1)+1;
        mh.autocalibrationmatrix(idx,1)=targpos(1);
        mh.autocalibrationmatrix(idx,2)=whereseye(1);
        mh.autocalibrationmatrix(idx,3)=targpos(2);
        mh.autocalibrationmatrix(idx,4)=whereseye(2);
    end
    [~,uidx]=unique(mh.autocalibrationmatrix(:,[1,3]),'last','rows');
    mh.autocalibrationmatrix=mh.autocalibrationmatrix(uidx,:);
end

centerx=(targposSquare(3)+targposSquare(1))/2;
centery=(targposSquare(4)+targposSquare(2))/2;
squarepos=round([centerx-radius centery-radius centerx+radius centery+radius]);
mh.Screen('FrameOval','monitoronly',[1 0 0],squarepos);
end