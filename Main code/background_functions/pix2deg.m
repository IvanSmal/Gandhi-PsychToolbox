function out = pix2deg(in,type)
%DEG2PIX Summary of this function goes here
%   Detailed explanation goes here
if ~exist('type','var')
    type='pol';
end

if ~exist('screenparams','var') || isempty(screenparams)
    %% get ini params
    ini=IniConfig();

    isini=ini.ReadFile('inis/ScreenParams.ini');

    if ~isini
        errordlg('ini not found. Missing or in the wrong path.')
    elseif isini
        PixelSize(1)=ini.GetValues('for deg2pix','xPixelSize');
        PixelSize(2)=ini.GetValues('for deg2pix','yPixelSize');
        trueCenter=ini.GetValues('for deg2pix','true center');
        distFromScreen=ini.GetValues('for deg2pix','subject distance');
    end
else
    PixelSize(1) = screenparams.xPixelSize;
    PixelSize(2) = screenparams.yPixelSize;
    trueCenter=screenparams.true_center;
    distFromScreen=screenparams.subject_distance;
end

%% do the calculations
for i=1:size(in,1)
    XYin=in(i,:);
    XYin(1)=XYin(1)-trueCenter(1);
    XYin(2)=-(XYin(2)-trueCenter(2));

    if matches(type,'size')
        XYin(1)=XYin(1)+trueCenter(1);
        XYin(2)=-XYin(2)+trueCenter(2);
        type='cart';
    end

    Xmm=XYin(1)*PixelSize(1);
    Ymm=XYin(2)*PixelSize(2);

    Xdeg=round(atand(Xmm/distFromScreen),2);
    Ydeg=round(atand(Ymm/distFromScreen),2);

    if matches(type,'cart',IgnoreCase=1) ||...
            matches(type,'cartesian',IgnoreCase=1)
        out(i,:)=[Xdeg, Ydeg];

    elseif matches(type,'pol',IgnoreCase=1) ||...
            matches(type,'polar',IgnoreCase=1)

        [t,rr]=cart2pol(Xdeg,Ydeg);
        theta=round(rad2deg(t),2);
        r=round(rr,2);
        out(i,:)=[theta r];
    end
end
out=rmmissing(out);
end

