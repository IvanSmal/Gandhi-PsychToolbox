function [frame, ok] = sceneRead(m, maxRetry)
%SCENEREAD Newest COMPLETE frame from the shared slot.
%   Returns a frame with the full published shape (seq, trialStarted,
%   stateName, setEye, resources, oneShots, cmds). ok=false only if the slot
%   kept tearing; an empty slot is not an error (nothing published yet) and
%   still returns ok=true with the empty frame below.
%
%   The empty frame must carry EVERY field a real frame does -- an empty slot
%   happens on the first run of a session and after a reboot clears
%   /dev/shm, and the renderer's draw loop reads frame.seq unconditionally,
%   so a frame missing it threw on every iteration until the state machine
%   published its first frame.
if nargin < 2, maxRetry = 8; end
L = sceneLayout();
ok = false;
frame = struct('seq',0,'tGenerated',0,'trialStarted',false,'stateName','null', ...
    'setEye',false,'resources',{{}},'oneShots',{{}},'cmds',{{}});
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
