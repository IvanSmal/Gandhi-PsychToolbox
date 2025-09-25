function [outputArg1,outputArg2] = makesound(mh, type, hz, amp, dur)
%MAKESOUND Summary of this function goes here
%   Detailed explanation goes here
%% generate command string
commid=num2str(mh.activestatetime);
tp='1';
if matches(type,'noise')
    tp='2';
elseif matches(type,'start')
    tp='3';
elseif matches(type,'reward')
    tp='4';
end

commstring=join(['GenerateSound_udp(app,',commid,',', tp,',', num2str(dur),',', num2str(amp),',', num2str(hz),');']);
%% send the thing using the reward port
writeline(mh.rewardport,commstring,'0.0.0.0',2025);
end

