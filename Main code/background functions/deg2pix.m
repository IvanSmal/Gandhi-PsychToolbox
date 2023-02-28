function out = deg2pix(in,type)
%DEG2PIX Summary of this function goes here
%   Detailed explanation goes here
if ~exist('type','var')
    type='cart';
end

%% get ini params
ini=IniConfig();

isini=ini.ReadFile('inis/ScreenParams.ini');

if ~isini
    errordlg('ini not found. Missing or in the wrong path.')
elseif isini
    degreesPerPixel(1)=ini.GetValues('for deg2pix','xDegreesPerPixel');
    degreesPerPixel(2)=ini.GetValues('for deg2pix','yDegreesPerPixel');
    trueCenter=ini.GetValues('for deg2pix','true center');
end 

%% do the calculations
for i=1:size(in,1)
    if matches(type,'cart',IgnoreCase=1) ||...
            matches(type,'cartesian',IgnoreCase=1)
        desiredXY=in(i,:);
    elseif matches(type,'pol',IgnoreCase=1) ||...
            matches(type,'polar',IgnoreCase=1)
        [desiredXY(1), desiredXY(2)]=pol2cart(deg2rad(in(i,1)),in(i,2));
    else
        errordlg('please specify either ''cart'' or ''pol''')
        return
    end
    out(i,1)=floor(trueCenter(1)+desiredXY(1)/degreesPerPixel(1));
    out(i,2)=floor(trueCenter(2)+desiredXY(2)/degreesPerPixel(2));
end
end

