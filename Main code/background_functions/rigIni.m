function ini = rigIni(which_file, inisDir)
%RIGINI Handle to this rig's config or state ini file.
%
%   ini = rigIni('config')  human-authored settings: screen geometry,
%                           deg2pix parameters, target windows, paths.
%                           Hand-edited, heavily commented, rarely changes.
%
%   ini = rigIni('state')   machine-written values: eye calibration, reward
%                           duration, remembered UI paths. Rewritten by the
%                           app every session - do not hand-edit while
%                           MHost2 is running.
%
%   These were historically one file (ScreenParams.ini), which meant the
%   app's automatic rewrites and the hand-written documentation lived in the
%   same place. They are now split by who owns them.
%
%   ScreenParams.ini keeps its name deliberately: the COMPILED RewardHandler
%   reads [reward] from that exact path and cannot be rebuilt from source
%   control, so the state file must stay where it expects it.
%
%   MIGRATION SAFETY: if RigConfig.ini does not exist yet, 'config' falls
%   back to ScreenParams.ini, which still holds every key. So a rig that has
%   not been migrated behaves exactly as before.

if nargin < 2 || isempty(inisDir)
    inisDir = 'inis';
end

CONFIG_FILE = fullfile(inisDir, 'RigConfig.ini');
STATE_FILE  = fullfile(inisDir, 'ScreenParams.ini');

switch lower(string(which_file))
    case "config"
        if isfile(CONFIG_FILE)
            target = CONFIG_FILE;
        else
            target = STATE_FILE;   % pre-migration fallback
        end
    case "state"
        target = STATE_FILE;
    otherwise
        error('rigIni:badArg', ...
            'which_file must be ''config'' or ''state'', got ''%s''.', which_file);
end

ini = IniConfig();
if ~ini.ReadFile(target)
    error('rigIni:readFailed', ...
        'Could not read "%s". Copy RigConfig.example.ini to RigConfig.ini and fill it in.', target);
end
end
