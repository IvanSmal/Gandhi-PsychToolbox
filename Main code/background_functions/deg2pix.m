function out = deg2pix(degIn, coordType, screenParams)
%DEG2PIX Convert degrees of visual angle to screen pixel coordinates.
%   The usual calls (finite double input; 'cart', 'pol', 'mm', 'mmsize', or a
%   single-row 'size') are computed for all rows at once: the task's eye and
%   target checks call this many times per loop pass. Everything else goes
%   through the original row-by-row code (deg2pixRows), which defines the
%   behaviour; both give the same numbers.
if ~exist('coordType','var') || isempty(coordType)
    coordType='pol';
end

if ~exist('screenParams','var') || isempty(screenParams)
    % No screen parameters passed: this rig's config file (RigConfig.ini, or
    % ScreenParams.ini on a rig that has not been migrated yet), cached.
    screenParams = rigGeometry();
end
px = screenParams.xPixelSize; py = screenParams.yPixelSize;
c = screenParams.true_center; d = screenParams.subject_distance;

n = size(degIn, 1);
if isa(degIn, 'double') && n > 0 && size(degIn, 2) >= 2 && all(isfinite(degIn(:))) ...
        && (ischar(coordType) || (isstring(coordType) && isscalar(coordType)))
    switch lower(char(coordType))
        case {'cart', 'cartesian'}
            out = [floor(c(1)+((tand(degIn(:,1))*d)/px)), floor(c(2)-((tand(degIn(:,2))*d)/py))];
            return
        case {'pol', 'polar'}
            [x, y] = pol2cart(deg2rad(degIn(:,1)), degIn(:,2));
            out = [floor(c(1)+((tand(x)*d)/px)), floor(c(2)-((tand(y)*d)/py))];
            return
        case 'mm'
            out = [floor(c(1)+(degIn(:,1)/px)), floor(c(2)-(degIn(:,2)/py))];
            return
        case 'mmsize'
            out = [zeros(n, 2), floor(degIn(:,1)/px), floor(degIn(:,2)/py)];
            return
        case 'size'
            if n == 1
                out = [0, 0, floor(((tand(degIn(1))*d)/px)), floor(((tand(degIn(2))*d)/py))];
                return
            end
    end
end
out = deg2pixRows(degIn, coordType, px, py, c, d);
end

% =========================================================================
function out = deg2pixRows(degIn, coordType, px, py, centerXY, distanceFromScreen)
% The original conversion, one row at a time.
out = []; % always assigned: empty input or an unrecognised type must not throw "output not assigned"
pixelSize = [px py];
for iRow=1:size(degIn,1)
    % 'mm' / 'mmsize': physical screen millimetres, mapped LINEARLY (no
    % visual-angle tangent). Origin is the same true center as 'cart', with +y
    % up. Additive: 'cart'/'pol'/'size'/'speed' below are unchanged.
    if matches(coordType,'mm',IgnoreCase=1)
        out(iRow,1)=floor(centerXY(1)+(degIn(iRow,1)/pixelSize(1)));
        out(iRow,2)=floor(centerXY(2)-(degIn(iRow,2)/pixelSize(2)));
        continue
    elseif matches(coordType,'mmsize',IgnoreCase=1)
        out(iRow,1)=0; out(iRow,2)=0;
        out(iRow,3)=floor(degIn(iRow,1)/pixelSize(1));
        out(iRow,4)=floor(degIn(iRow,2)/pixelSize(2));
        continue
    end
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
end
