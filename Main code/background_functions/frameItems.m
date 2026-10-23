function [a, b, c, d] = frameItems(op, x, y)
%FRAMEITEMS The items the frame being built draws on the display (stimulus timing).
%   frameItems('target', name, rect)  getpos returned RECT for target NAME; a
%                                     drawing command at that rectangle shows it
%   frameItems('draw', args, tag)     a display drawing command (mh.Screen
%                                     arguments, window already resolved). TAG
%                                     from its 'Tag' pair; '' to match a target
%   [names, kinds, rects, changes] = frameItems('take', state)
%                                     this frame's items (rects: bounding box
%                                     per item, display pixels, NaN if unknown)
%                                     and what changed since the last frame:
%                                     n x 3 {tag, kind, event}, event 'on',
%                                     'off' or 'state' (photodiode). Clears the
%                                     frame for the next one.
%   frameItems('clear')               drop this frame's items (clearbuffer)
%   frameItems('reset')               new trial: nothing on screen, no state
%
%   Same-named commands in one frame are one item whose box covers them all.
%   State lives here rather than in the internal object, in few persistent
%   variables and fixed-size buffers: this runs in the 1 kHz loop. See
%   buildStimulusTiming for how the tables are made.
persistent F T P
% F: this frame's items   T: getpos rectangles since the last frame
% P: previous frame's item names, kinds and state
if isempty(F)
    F = struct('n', 0, 'names', {cell(1, 16)}, 'kinds', {cell(1, 16)}, 'rects', zeros(16, 4));
    T = struct('n', 0, 'names', {cell(1, 16)}, 'rects', zeros(16, 4));
    P = {{}, {}, ''};
end
switch op
    case 'target'
        n = T.n + 1;
        if n > 16, return, end                          % more than 16 per frame: ignore the rest
        T.names{n} = x; T.rects(n, :) = y; T.n = n;
    case 'draw'
        kind = 'tag';
        if isempty(y)
            if T.n == 0, return, end                    % no target positions to match
            [p, rect] = drawnAt(x);
            if numel(p) ~= 4, return, end               % targets are drawn at a rectangle
            p = double(p);
            k = T.n;
            while k > 0 && ~(T.rects(k,1) == p(1) && T.rects(k,2) == p(2) && T.rects(k,3) == p(3) && T.rects(k,4) == p(4))
                k = k - 1;
            end
            if k == 0, return, end
            y = T.names{k};
            kind = 'target';
        else
            [~, rect] = drawnAt(x);
            if isempty(rect), rect = nan(1, 4); end
        end
        j = find(strcmp(F.names(1:F.n), y), 1);
        if isempty(j)
            n = F.n + 1;
            if n > 16, return, end
            F.names{n} = y; F.kinds{n} = kind; F.rects(n, :) = rect; F.n = n;
        else                                            % min/max skip NaN (an unknown box)
            F.rects(j, :) = [min(F.rects(j, 1:2), rect(1:2)), max(F.rects(j, 3:4), rect(3:4))];
        end
    case 'take'
        n = F.n;
        a = F.names(1:n); b = F.kinds(1:n); c = F.rects(1:n, :);
        d = cell(0, 3);
        if ~(isequal(a, P{1}) && strcmp(x, P{3}))      % usually nothing changed
            if ~strcmp(x, P{3}), d(end+1, :) = {'photodiode', 'photodiode', 'state'}; end
            for j = find(~ismember(a, P{1})), d(end+1, :) = {a{j}, b{j}, 'on'}; end %#ok<AGROW>
            for j = find(~ismember(P{1}, a)), d(end+1, :) = {P{1}{j}, P{2}{j}, 'off'}; end %#ok<AGROW>
            P = {a, b, x};
        end
        F.n = 0; T.n = 0;
    case 'clear'
        F.n = 0;
    case 'reset'
        F.n = 0; T.n = 0;
        P = {{}, {}, ''};
end
end

function [p, rect] = drawnAt(args)
% Where a drawing command draws. P is the argument holding the position, as
% the task passed it (to match getpos output); RECT is its bounding box
% [left top right bottom] in display pixels. Both [] when unknown.
p = []; rect = [];
switch lower(args{1})
    case {'fillrect','framerect','filloval','frameoval','fillarc','framearc','drawarc','fillpoly','framepoly'}
        i = 4;                              % (window, colour, rect / points)
    case {'drawtexture','drawtextures'}
        i = 5;                              % (window, texture, sourceRect, destinationRect)
    case {'drawdots','drawlines'}
        i = 3;                              % (window, xy, ...), centre offset 6th
    case 'drawline'                         % (window, colour, fromH, fromV, toH, toV)
        if numel(args) >= 7 && all(cellfun(@(v) isnumeric(v) && isscalar(v), args(4:7)))
            p = double([args{4:7}]);
            rect = [min(p([1 3])), min(p([2 4])), max(p([1 3])), max(p([2 4]))];
        end
        return
    case 'drawtext'                         % (window, text, x, y): a point
        if numel(args) >= 5 && isnumeric(args{4}) && isscalar(args{4}) && isnumeric(args{5}) && isscalar(args{5})
            p = double([args{4} args{5}]);
            rect = [p p];
        end
        return
    otherwise
        return
end
if numel(args) < i || ~isnumeric(args{i}) || isempty(args{i}), return, end
p = args{i};
v = double(p);
switch lower(args{1})
    case {'drawdots','drawlines'}           % 2 x n points
        if size(v, 1) ~= 2, v = v.'; end
        if size(v, 1) ~= 2, p = []; return, end
        cc = [0 0];
        if numel(args) >= 6 && isnumeric(args{6}) && numel(args{6}) == 2, cc = double(args{6}(:)'); end
        rect = [min(v(1,:)) + cc(1), min(v(2,:)) + cc(2), max(v(1,:)) + cc(1), max(v(2,:)) + cc(2)];
    case {'fillpoly','framepoly'}           % n x 2 points
        if size(v, 2) ~= 2, p = []; return, end
        rect = [min(v(:,1)), min(v(:,2)), max(v(:,1)), max(v(:,2))];
    otherwise                               % a rect, or 4 x n rects
        if numel(v) == 4
            rect = [v(1), v(2), v(3), v(4)];
        elseif size(v, 1) == 4
            rect = [min(v(1,:)), min(v(2,:)), max(v(3,:)), max(v(4,:))];
        else
            p = [];
        end
end
end
