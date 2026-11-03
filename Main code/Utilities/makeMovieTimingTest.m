function file = makeMovieTimingTest(file, varargin)
%MAKEMOVIETIMINGTEST Write a test movie for checking movie timing on a rig.
%   makeMovieTimingTest(FILE) writes an AVI (Motion JPEG, which GStreamer
%   plays) whose every frame says which frame it is, three ways:
%     - a square in the top-left corner, WHITE on odd frames and BLACK on
%       even ones (frame 1 = the first): with the photodiode over it, every
%       change of movie frame is a step in the photodiode trace;
%     - the frame number in large digits, for people or a camera;
%     - the frame number as a row of 12 bits along the bottom (white = 1,
%       most significant bit on the left).
%   Options, as name / value pairs:
%     'fps'      frame rate (default 30)
%     'seconds'  length (default 10)
%     'size'     [width height] in pixels (default [640 360])
%     'patch'    the corner square's side, as a fraction of the height (0.3)
%   Then declare it in a parameter file (mh.addmovie(name, FILE)), draw it
%   so the square lands under the photodiode, record with the photodiode
%   there, and compare with movieTimingCheck. documentation/timing.md has
%   the steps.
p = inputParser;
p.addParameter('fps', 30);
p.addParameter('seconds', 10);
p.addParameter('size', [640 360]);
p.addParameter('patch', 0.3);
p.parse(varargin{:});
o = p.Results;
W = o.size(1); H = o.size(2);
n = round(o.fps * o.seconds);
side = round(o.patch * H);
v = VideoWriter(file, 'Motion JPEG AVI');
v.FrameRate = o.fps;
v.Quality = 95;
open(v);
cleanup = onCleanup(@() close(v));
digitH = round(0.4 * H); digitW = round(0.55 * digitH); gap = round(0.15 * digitW);
bitW = floor(W / 12); bitH = max(4, round(0.08 * H));
for k = 1:n
    img = zeros(H, W, 'uint8') + 60;                       % dark grey
    img(1:side, 1:side) = 255 * mod(k, 2);                 % odd frames white
    % the frame number in digits, right of the square
    s = sprintf('%d', k);
    x0 = side + round(0.05 * W); y0 = round(0.12 * H);
    for c = 1:numel(s)
        img = drawDigit(img, s(c) - '0', x0 + (c - 1) * (digitW + gap), y0, digitW, digitH);
    end
    % the frame number in 12 bits along the bottom
    b = bitget(k, 12:-1:1);
    for j = 1:12
        img(H - bitH + 1:H, (j - 1) * bitW + 1:j * bitW - 2) = 255 * b(j);
    end
    writeVideo(v, repmat(img, 1, 1, 3));
end
clear cleanup
fprintf('wrote %s: %d frames, %g fps, %d x %d\n', file, n, o.fps, W, H);
end

function img = drawDigit(img, d, x, y, w, h)
% A seven-segment digit, white, with its top-left corner at (x, y).
%        a: top, b: top right, c: bottom right, d: bottom, e: bottom left,
%        f: top left, g: middle
on = [1 1 1 1 1 1 0; 0 1 1 0 0 0 0; 1 1 0 1 1 0 1; 1 1 1 1 0 0 1; 0 1 1 0 0 1 1; ...
      1 0 1 1 0 1 1; 1 0 1 1 1 1 1; 1 1 1 0 0 0 0; 1 1 1 1 1 1 1; 1 1 1 1 0 1 1];
t = max(2, round(0.15 * w)); m = round(h / 2);
seg = {[y, y + t - 1, x, x + w - 1], [y, y + m, x + w - t, x + w - 1], ...
       [y + m, y + h - 1, x + w - t, x + w - 1], [y + h - t, y + h - 1, x, x + w - 1], ...
       [y + m, y + h - 1, x, x + t - 1], [y, y + m, x, x + t - 1], ...
       [y + m - floor(t / 2), y + m - floor(t / 2) + t - 1, x, x + w - 1]};
for i = find(on(d + 1, :))
    r = seg{i};
    rows = max(1, r(1)):min(size(img, 1), r(2));
    cols = max(1, r(3)):min(size(img, 2), r(4));
    img(rows, cols) = 255;
end
end
