function [frame, ok] = sceneRead(m, maxRetry)
%SCENEREAD Newest COMPLETE frame from the shared slot.
%   frame has fields .trialStarted .stateName .cmds, or ok=false if the slot
%   is empty or kept tearing. An empty slot is not an error: it simply means
%   nothing has been published yet.
if nargin < 2, maxRetry = 8; end
L = sceneLayout();
ok = false;
frame = struct('trialStarted',false,'stateName','null','cmds',{{}});
for k = 1:maxRetry
    hdr = m.Data.s(L.SEQ:L.NBYTES);
    seq = hdr(1); n = hdr(2);
    if seq == 0 || n <= 0
        ok = true;          % nothing published yet: a valid empty frame
        return
    end
    if n > (L.CAP - 3)*1, continue; end
    rec = m.Data.s(1:n+3);
    if rec(1) ~= rec(end), continue; end       % torn: retry
    try
        frame = getArrayFromByteStream(uint8(rec(L.DATA0:L.DATA0+n-1)));
        ok = true;
        return
    catch
        % payload not yet consistent; retry
    end
end
end
