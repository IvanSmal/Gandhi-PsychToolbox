function iniPath = rigIniPath(which_file, inisDir)
%RIGINIPATH Path to this rig's config or state ini file, without reading it.
%
%   'config' -> RigConfig.ini    hand-written rig settings
%   'state'  -> ScreenParams.ini machine-written values
%
%   'config' falls back to ScreenParams.ini when RigConfig.ini does not
%   exist, so callers behave identically on a rig that has not been
%   migrated yet. rigIni rejects that fallback once it detects the file is
%   not actually a config file, so a migrated rig fails loudly instead of
%   handing back empty values. See rigIni for the full rationale.

if nargin < 2 || isempty(inisDir)
    % Resolve relative to THIS FILE, not the current directory. Callers run
    % from varying working directories, and a cwd-relative 'inis' resolved
    % to nothing - which made the config fallback pick ScreenParams.ini, a
    % file that no longer holds the config sections after migration, and
    % return empty values instead of failing.
    here    = fileparts(mfilename('fullpath'));   % .../Main code/background_functions
    inisDir = fullfile(fileparts(here), 'inis');  % .../Main code/inis
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
