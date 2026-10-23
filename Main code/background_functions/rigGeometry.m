function g = rigGeometry()
%RIGGEOMETRY This rig's display geometry, from its config's [for deg2pix].
%   g has the fields of mh.screenparams that deg2pix / pix2deg use:
%   xPixelSize, yPixelSize, true_center, subject_distance. deg2pix / pix2deg
%   use it when they are called without screen parameters (GraphicsHandler,
%   the stimulus timing tables, ...). The file is parsed once and again only
%   when it changes, checked at most once a second; parsing it on every call
%   cost milliseconds.
persistent cache stamp sinceCheck
if isempty(cache) || toc(sinceCheck) > 1
    sinceCheck = tic;
    p = rigIniPath('config', '');
    f = dir(p);
    s = '';
    if ~isempty(f), s = sprintf('%s|%.12g|%d', p, f.datenum, f.bytes); end
    if isempty(cache) || ~strcmp(s, stamp)
        ini = rigIni('config');
        cache = struct('xPixelSize', ini.GetValues('for deg2pix','xPixelSize'), ...
            'yPixelSize', ini.GetValues('for deg2pix','yPixelSize'), ...
            'true_center', ini.GetValues('for deg2pix','true center'), ...
            'subject_distance', ini.GetValues('for deg2pix','subject distance'));
        stamp = s;
    end
end
g = cache;
end
