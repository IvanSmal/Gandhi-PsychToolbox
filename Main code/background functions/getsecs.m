function out = getsecs
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

[~, ~, ~, H, M, S] = datevec(now);
out = H*3600+M*60+S;
end

