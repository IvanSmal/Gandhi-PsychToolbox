function iniPath = rigIniPath(which_file, inisDir)
%RIGINIPATH Path to this rig's config or state ini file, without reading it.
%
%   'config' -> RigConfig.ini   hand-written rig settings
%   'state'  -> ScreenParams.ini machine-written values
%
%   'config' falls back to ScreenParams.ini when RigConfig.ini does not
%   exist, so callers behave identically on an unmigrated rig.
%   See rigIni for the full rationale.

if nargin < 2 || isempty(inisDir)
    inisDir = 'inis';
end
CONFIG_FILE = fullfile(inisDir, 'RigConfig.ini');
STATE_FILE  = fullfile(inisDir, 'ScreenParams.ini');

switch lower(string(which_file))
    case "config"
        if isfile(CONFIG_FILE)
            iniPath = CONFIG_FILE;
        else
            iniPath = STATE_FILE;   % pre-migration fallback
        end
    case "state"
        iniPath = STATE_FILE;
    otherwise
        error('rigIniPath:badArg', ...
            'which_file must be ''config'' or ''state'', got ''%s''.', which_file);
end
end
