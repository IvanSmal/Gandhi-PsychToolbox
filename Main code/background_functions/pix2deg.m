function out = pix2deg(pixIn, coordType, screenParams)
%PIX2DEG Convert screen pixel coordinates to degrees of visual angle.
%   The usual calls (finite double input; 'cart', 'pol', 'mm', 'mmsize',
%   'size') are computed for all rows at once: the task's eye and target
%   checks call this many times per loop pass. Everything else goes through
%   the original row-by-row code (pix2degRows), which defines the behaviour;
%   both give the same numbers.
if ~exist('coordType','var')
    coordType='cart';
end

if ~exist('screenParams','var') || isempty(screenParams)
    % No screen parameters passed: this rig's config file (RigConfig.ini, or
    % ScreenParams.ini on a rig that has not been migrated yet), cached.
    screenParams = rigGeometry();
end
px = screenParams.xPixelSize; py = screenParams.yPixelSize;
c = screenParams.true_center; d = screenParams.subject_distance;

n = size(pixIn, 1);
if isa(pixIn, 'double') && n > 0 && size(pixIn, 2) >= 2 && all(isfinite(pixIn(:))) ...
        && (ischar(coordType) || (isstring(coordType) && isscalar(coordType)))
    t = char(coordType);
    x = pixIn(:,1)-c(1);
    y = -(pixIn(:,2)-c(2));
    if strcmp(t, 'size')
        % as the original: the first row is an extent; it then carries on
        % as 'cart' for any further rows
        x(1) = x(1)+c(1);
        y(1) = -y(1)+c(2);
        t = 'cart';
    end
    switch lower(t)
        case 'mm'
            out = [x*px, y*py];
            return
        case 'mmsize'
            out = [abs(pixIn(:,1))*px, abs(pixIn(:,2))*py];
            return
        case {'cart', 'cartesian'}
            out = [round(atand((x*px)/d),2), round(atand((y*py)/d),2)];
            return
        case {'pol', 'polar'}
            [thetaRad, radiusRaw] = cart2pol(round(atand((x*px)/d),2), round(atand((y*py)/d),2));
            out = [round(rad2deg(thetaRad),2), round(radiusRaw,2)];
            return
    end
end
out = pix2degRows(pixIn, coordType, px, py, c, d);
end

% =========================================================================
function out = pix2degRows(pixIn, coordType, px, py, trueCenter, distFromScreen)
% The original conversion, one row at a time.
out = []; % always assigned: empty input must not throw "output not assigned"
pixelSize = [px py];
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

    % 'mm' / 'mmsize': physical millimetres (linear inverse of deg2pix mm).
    % 'mm' is a position relative to the true center; 'mmsize' is an extent.
    if matches(coordType,'mm',IgnoreCase=1)
        out(iRow,:)=[xMm, yMm];
        continue
    elseif matches(coordType,'mmsize',IgnoreCase=1)
        out(iRow,:)=[abs(pixIn(iRow,1))*pixelSize(1), abs(pixIn(iRow,2))*pixelSize(2)];
        continue
    end

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
