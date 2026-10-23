function disableDemoXippmex(realXippmexPath)
%DISABLEDEMOXIPPMEX Leave demo mode: go back to the real xippmex.
%   Removes the demo flag and the mock folder from the path, re-adds the real
%   xippmex folder, and clears/rehashes so xippmex resolves to the real MEX
%   again. Mirror of enableDemoXippmex. (Reconnecting to live Trellis mid-session
%   may still want a process restart; this just restores xippmex resolution.)
try, delete(demoFlagPath()); catch, end
demoDir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'demo_xippmex');
try, rmpath(demoDir); catch, end
if nargin >= 1 && ~isempty(realXippmexPath)
    try, addpath(realXippmexPath); catch, end
end
try, clear xippmex; catch, end
try, rehash; catch, end
end
