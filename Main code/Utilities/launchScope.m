% Launcher for TrellisScope with the real xippmex source, invoked from
% MonkeyHost's Utils menu. Sets up the path (Main code for rigIni/pix2deg, and
% the xippmex folder) then opens the scope reading live Trellis data. If demo
% mode is active (the flag file exists), swap to the simulated xippmex so the
% scope runs without Trellis too.
here = fileparts(mfilename('fullpath'));
maincode = fileparts(here);
addpath(genpath(maincode));
xippmexPath = '/opt/Trellis/Tools/xippmex';
try
    fp = IniConfig();
    fp.ReadFile(fullfile(maincode, 'inis', 'FilePaths.ini'));
    xippmexPath = fp.GetValues('paths', 'xippmex');
catch
end
addpath(xippmexPath);
if isfile(demoFlagPath())
    try, enableDemoXippmex(xippmexPath); catch, end
end
TrellisScope('sim', 0);
