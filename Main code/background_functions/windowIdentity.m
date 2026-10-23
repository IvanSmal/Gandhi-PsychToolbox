function windowIdentity(title, key, fig)
%WINDOWIDENTITY Give a window its own entry and icon in the desktop dock.
%   windowIdentity(TITLE, KEY) finds the window titled TITLE and sets its X
%   WM_CLASS to Gandhi<Key>, and makes sure ~/.local/share/applications has a
%   matching gandhi-<key>.desktop entry showing assets/icons/<key>.png.
%   windowIdentity(TITLE, KEY, FIG) also sets FIG.Icon (title bar, Alt-Tab).
%
%   GNOME's dock groups windows by WM_CLASS and shows the icon of the .desktop
%   entry whose StartupWMClass matches; a figure's own Icon never reaches it.
%   Every MATLAB window shares one class and Psychtoolbox windows have none, so
%   without this they all show as the same generic gear.
%
%   Only MATLAB figure windows and class-less (Psychtoolbox) windows are
%   re-classed: a terminal or mutter frame with the same title is left alone.
%   The search runs in the background, retrying for up to 60 s until the window
%   is mapped (GraphicsHandler's info window appears only once its render loop
%   is running), so the caller is never held up. Needs xdotool and xprop (X11);
%   without xdotool this does nothing (said once per session).

persistent warned
if ~isunix || ismac, return; end

here = fileparts(mfilename('fullpath'));                    % .../Main code/background_functions
icon = fullfile(fileparts(here), 'assets', 'icons', [key '.png']);
cls  = ['Gandhi' upper(key(1)) key(2:end)];

if nargin >= 3 && ~isempty(fig) && isfile(icon)
    try, fig.Icon = icon; catch, end
end

if system('command -v xdotool >/dev/null 2>&1') ~= 0
    if isempty(warned)
        warned = true;
        disp('windowIdentity: xdotool is not installed, so windows keep the generic dock icon (sudo apt install xdotool)');
    end
    return
end

% the .desktop entry the dock matches the class against (rewritten only if it changed)
appdir = fullfile(getenv('HOME'), '.local', 'share', 'applications');
entry  = sprintf(['[Desktop Entry]\nType=Application\nName=%s\nExec=/bin/true\nIcon=%s\n' ...
                  'StartupWMClass=%s\nNoDisplay=true\n'], title, icon, cls);
efile  = fullfile(appdir, ['gandhi-' key '.desktop']);
try
    if ~isfile(efile) || ~strcmp(fileread(efile), entry)
        if ~isfolder(appdir), mkdir(appdir); end
        fid = fopen(efile, 'w'); fwrite(fid, entry); fclose(fid);
    end
catch
end

% xdotool --name takes a regular expression: anchor and escape the title.
% MATLAB's LD_LIBRARY_PATH is dropped first: its bundled libraries can break
% the X11 tools system() starts (the same reason gnome-terminal fails from here).
pat = ['^' regexptranslate('escape', title) '$'];
cmd = sprintf(['(unset LD_LIBRARY_PATH; for i in $(seq 1 120); do tagged=; ' ...
    'for w in $(xdotool search --onlyvisible --name ''%s'' 2>/dev/null); do ' ...
    'case "$(xprop -id $w WM_CLASS 2>/dev/null)" in ' ...
    '*Matlab-GLEE*|*"not found"*) xdotool set_window --classname %s --class %s $w; tagged=1;; ' ...
    'esac; done; [ -n "$tagged" ] && exit 0; sleep 0.5; done) >/dev/null 2>&1 &'], ...
    pat, lower(cls), cls);
system(cmd);
end
