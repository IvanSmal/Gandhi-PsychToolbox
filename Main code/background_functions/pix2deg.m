function out = pix2deg(pixIn, coordType, screenParams)
%PIX2DEG Convert screen pixel coordinates to degrees of visual angle.
out = []; % always assigned: empty input must not throw "output not assigned"
if ~exist('coordType','var')
    coordType='cart';
end

if ~exist('screenParams','var') || isempty(screenParams)
    %% get ini params
    ini=IniConfig();

    isIniLoaded=ini.ReadFile('inis/ScreenParams.ini');

    if ~isIniLoaded
        errordlg('ini not found. Missing or in the wrong path.')
    elseif isIniLoaded
        pixelSize(1)=ini.GetValues('for deg2pix','xPixelSize');
        pixelSize(2)=ini.GetValues('for deg2pix','yPixelSize');
        trueCenter=ini.GetValues('for deg2pix','true center');
        distFromScreen=ini.GetValues('for deg2pix','subject distance');
    end
else
    pixelSize(1) = screenParams.xPixelSize;
    pixelSize(2) = screenParams.yPixelSize;
    trueCenter=screenParams.true_center;
    distFromScreen=screenParams.subject_distance;
end

%% do the calculations
for iRow=1:size(pixIn,1)
    xyIn=pixIn(iRow,:);
    xyIn(1)=xyIn(1)-trueCenter(1);
    xyIn(2)=-(xyIn(2)-trueCenter(2));

    if matches(coordType,'size')
        xyIn(1)=xyIn(1)+trueCenter(1);
        xyIn(2)=-xyIn(2)+trueCenter(2);
        coordType='cart';
    end

    xMm=xyIn(1)*pixelSize(1);
    yMm=xyIn(2)*pixelSize(2);

    xDeg=round(atand(xMm/distFromScreen),2);
    yDeg=round(atand(yMm/distFromScreen),2);

    if matches(coordType,'cart',IgnoreCase=1) ||...
            matches(coordType,'cartesian',IgnoreCase=1)
        out(iRow,:)=[xDeg, yDeg];

    elseif matches(coordType,'pol',IgnoreCase=1) ||...
            matches(coordType,'polar',IgnoreCase=1)

        [thetaRad,radiusRaw]=cart2pol(xDeg,yDeg);
        theta=round(rad2deg(thetaRad),2);
        r=round(radiusRaw,2);
        out(iRow,:)=[theta r];
    end
end
if any(isempty(out)) || any(any(isnan(out)))
    out=rmmissing(out);
end
end
