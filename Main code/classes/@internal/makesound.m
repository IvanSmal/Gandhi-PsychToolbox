function [outputArg1,outputArg2] = makesound(mh, soundType, freqHz, amplitude, durationSec)
%MAKESOUND Ask the SoundGenerator process to play a tone or cue.
%   soundType: 'sine' (default), 'noise', 'start' or 'reward'.
%% generate command string
commandId=num2str(mh.activestatetime);
soundTypeCode='1';
if matches(soundType,'noise')
    soundTypeCode='2';
elseif matches(soundType,'start')
    soundTypeCode='3';
elseif matches(soundType,'reward')
    soundTypeCode='4';
end

% GenerateSound_udp is the SoundGenerator process's own function name - it is
% evaluated on the far side of the UDP link, so it must not be renamed here.
commandString=join(['GenerateSound_udp(app,',commandId,',', soundTypeCode,',', num2str(durationSec),',', num2str(amplitude),',', num2str(freqHz),');']);
%% send the thing using the reward port
writeline(mh.rewardport,commandString,'0.0.0.0',2025);
end

