function stim(mh, ip, port)
%STIM Trigger the external stim script, at most once per trial.
%   mh.stim             send to the stim PC set in RigConfig.ini [stim]
%   mh.stim(ip)         send to another host, on the configured port
%   mh.stim(ip, port)   send to another host and port
%
%   Sends one byte over UDP. The stim scripts (SimpleSequentialStim*,
%   Triggeredstim_*) block on read(U,1) and fire on any byte. A wrong
%   address fails silently, so the script just keeps waiting.
if ~mh.stimmed
    [cfgIp, cfgPort] = stimDestination();
    if nargin < 2 || isempty(ip),   ip   = cfgIp;   end
    if nargin < 3 || isempty(port), port = cfgPort; end
    write(mh.graphicsport,1,char(ip),port)
    mh.stimflip=abs(mh.stimflip-1);
    mh.stimmed=1;
end
end
