function [host, port] = stimDestination()
%STIMDESTINATION Where mh.stim sends its trigger: RigConfig.ini [stim].
%   Read once per MATLAB session and cached, so the trigger itself never
%   waits on a file read. Restart MHost2 after editing [stim].
%
%   A config with no [stim] section gets the stim PC, 192.168.42.200:2028,
%   so legacy stim scripts work without configuring anything. stim.m used
%   to hardcode 192.168.42.2, which nothing answers; UDP never reports an
%   unreachable host, so the stim script just waited forever.
persistent cachedHost cachedPort
if isempty(cachedHost)
    cachedHost = '192.168.42.200';
    cachedPort = 2028;
    ini = rigIni('config');
    if ini.IsSections('stim')
        h = ini.GetValues('stim','host');
        p = ini.GetValues('stim','port');
        if ~isempty(h), cachedHost = char(string(h)); end
        if ~isempty(p), cachedPort = p; end
    else
        fprintf(['stimDestination: no [stim] section in %s; using %s:%d.\n' ...
                 '    Add [stim] host=/port= if that is not the stim PC.\n'], ...
                rigIniPath('config'), cachedHost, cachedPort);
    end
end
host = cachedHost;
port = cachedPort;
end
