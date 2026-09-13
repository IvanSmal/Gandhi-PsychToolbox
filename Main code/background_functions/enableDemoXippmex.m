function enableDemoXippmex(realXippmexPath)
%ENABLEDEMOXIPPMEX Switch this process to the simulated (mock) xippmex.
%   Removes the real xippmex folder from the path, adds the demo folder (which
%   holds the mock xippmex.m), clears the cached real MEX and rehashes so the
%   mock resolves next. Drops the demo flag file so every process (and the mock
%   itself) knows demo mode is active. Safe to call more than once.
if nargin >= 1 && ~isempty(realXippmexPath)
    try, warning('off','MATLAB:rmpath:DirNotFound'); rmpath(genpath(realXippmexPath)); catch, end
end
% The mock lives OUTSIDE "Main code" (a sibling folder) so that the app's
% addpath(genpath(home)) never puts it on the path in normal mode -- it is added
% here, and only here, when demo mode is turned on.
demoDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'demo_xippmex');
try, addpath(demoDir); catch, end
try, fid = fopen(demoFlagPath(), 'w'); fwrite(fid, '1'); fclose(fid); catch, end
try, clear xippmex; catch, end     % drop the cached real MEX so the mock .m wins
try, rehash; catch, end
end
