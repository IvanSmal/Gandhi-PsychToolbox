function out = deg2pix(in,type,screenparams)
%DEG2PIX Summary of this function goes here
%  Detailed explanation goes here
if ~exist('type','var') || isempty(type)
    type='pol';
end


if ~exist('screenparams','var') || isempty(screenparams)
    % get ini params

    ini=IniConfig();

    isini=ini.ReadFile('inis/ScreenParams.ini');

    if ~isini
        errordlg('ini not found. Missing or in the wrong path.')
    elseif isini
        PixelSize(1)=ini.GetValues('for deg2pix','xPixelSize');
        PixelSize(2)=ini.GetValues('for deg2pix','yPixelSize');
        centerXY=ini.GetValues('for deg2pix','true center');
        distanceFromScreen=ini.GetValues('for deg2pix','subject distance');
    end
else
    PixelSize(1) = screenparams.xPixelSize;
    PixelSize(2) = screenparams.yPixelSize;
    centerXY=screenparams.true_center;
    distanceFromScreen=screenparams.subject_distance;
end

% do the calculations
for i=1:size(in,1)
    if matches(type,'cart',IgnoreCase=1) ||...
            matches(type,'cartesian',IgnoreCase=1)
        desiredXY=in(i,:);
    elseif matches(type,'pol',IgnoreCase=1) ||...
            matches(type,'polar',IgnoreCase=1)
        [desiredXY(1), desiredXY(2)]=pol2cart(deg2rad(in(i,1)),in(i,2));
    elseif matches(type,'size',IgnoreCase=1)
        desiredXY=in(i,:);
    elseif matches(type,'speed',IgnoreCase=1)
        desiredXY=[in(i) 0];
    else
        errordlg('please specify either ''cart'' or ''pol''')
        return
    end

    out(i,1)=floor(centerXY(1)+((tand(desiredXY(1))*distanceFromScreen)/PixelSize(1)));
    out(i,2)=floor(centerXY(2)-((tand(desiredXY(2))*distanceFromScreen)/PixelSize(2)));

    if matches(type,'size',IgnoreCase=1)
        clear out
        out(i,1)=0;
        out(i,2)=0;
        out(i,3)=floor(((tand(desiredXY(1))*distanceFromScreen)/PixelSize(1)));
        out(i,4)=floor(((tand(desiredXY(2))*distanceFromScreen)/PixelSize(2)));
    end

    if matches(type,'speed',IgnoreCase=1)
        clear out
        out=floor(((tand(desiredXY(1))*distanceFromScreen)/PixelSize(1)));
    end
end

