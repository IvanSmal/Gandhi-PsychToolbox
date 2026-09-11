function out = deg2pix(degIn, coordType, screenParams)
%DEG2PIX Convert degrees of visual angle to screen pixel coordinates.
out = []; % always assigned: empty input or an unrecognised type must not throw "output not assigned"
if ~exist('coordType','var') || isempty(coordType)
    coordType='pol';
end


if ~exist('screenParams','var') || isempty(screenParams)
    % No screen parameters passed: read this rig's config file.
    % rigIni('config') returns RigConfig.ini, or falls back to
    % ScreenParams.ini on a rig that has not been migrated yet.
    ini = rigIni('config');
    pixelSize(1)=ini.GetValues('for deg2pix','xPixelSize');
    pixelSize(2)=ini.GetValues('for deg2pix','yPixelSize');
    centerXY=ini.GetValues('for deg2pix','true center');
    distanceFromScreen=ini.GetValues('for deg2pix','subject distance');
else
    pixelSize(1) = screenParams.xPixelSize;
    pixelSize(2) = screenParams.yPixelSize;
    centerXY=screenParams.true_center;
    distanceFromScreen=screenParams.subject_distance;
end

% do the calculations
for iRow=1:size(degIn,1)
    if matches(coordType,'cart',IgnoreCase=1) ||...
            matches(coordType,'cartesian',IgnoreCase=1)
        desiredXY=degIn(iRow,:);
    elseif matches(coordType,'pol',IgnoreCase=1) ||...
            matches(coordType,'polar',IgnoreCase=1)
        [desiredXY(1), desiredXY(2)]=pol2cart(deg2rad(degIn(iRow,1)),degIn(iRow,2));
    elseif matches(coordType,'size',IgnoreCase=1)
        desiredXY=degIn(iRow,:);
    elseif matches(coordType,'speed',IgnoreCase=1)
        desiredXY=[degIn(iRow) 0];
    else
        errordlg('please specify either ''cart'' or ''pol''')
        return
    end
    
    out(iRow,1)=floor(centerXY(1)+((tand(desiredXY(1))*distanceFromScreen)/pixelSize(1)));
    out(iRow,2)=floor(centerXY(2)-((tand(desiredXY(2))*distanceFromScreen)/pixelSize(2)));

    if matches(coordType,'size',IgnoreCase=1)
        clear out
        out(iRow,1)=0;
        out(iRow,2)=0;
        out(iRow,3)=floor(((tand(desiredXY(1))*distanceFromScreen)/pixelSize(1)));
        out(iRow,4)=floor(((tand(desiredXY(2))*distanceFromScreen)/pixelSize(2)));
    end

    if matches(coordType,'speed',IgnoreCase=1)
        clear out
        out=floor(((tand(desiredXY(1))*distanceFromScreen)/pixelSize(1)));
    end
    if any(isempty(out)) || any(any(isnan(out)))
        out=rmmissing(out);
    end
end
