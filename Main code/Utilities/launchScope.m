% Launcher for TrellisScope with the real xippmex source, invoked from
% MonkeyHost's Utils menu. Sets up the path (Main code for rigIni/pix2deg, and
% the xippmex folder) then opens the scope reading live Trellis data.
here = fileparts(mfilename('fullpath'));
maincode = fileparts(here);
addpath(genpath(maincode));
try
    fp = IniConfig();
    fp.ReadFile(fullfile(maincode, 'inis', 'FilePaths.ini'));
    addpath(fp.GetValues('paths', 'xippmex'));
catch
    addpath('/opt/Trellis/Tools/xippmex');
end
TrellisScope('sim', 0);
