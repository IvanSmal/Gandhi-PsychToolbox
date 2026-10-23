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
%
%   Sequence lock (see sceneWrite): the head is read before and after the
%   frame, and the frame is kept only if both are the same positive seq, and
%   the tail matches. A negative head means a write is in progress. Checking
%   only the two ends was not enough: in a two-process test a new, shorter
%   frame left the old tail in place and 34 of 4259 frames read came out
%   mixed from two writes.
if nargin < 2, maxRetry = 8; end
L = sceneLayout();
ok = false;
frame = struct('seq',0,'tGenerated',0,'trialStarted',false,'stateName','null', ...
    'setEye',false,'resources',{{}},'oneShots',{{}},'cmds',{{}});
fid = m.fid;
% Retry at least maxRetry times and for up to 2 ms: a write in progress
% (head < 0) lasts tens of microseconds, longer if the writer is descheduled,
% and 8 quick retries alone gave up on 0.3% of reads at 1.5 kHz writes.
t0 = tic; k = 0;
while k < maxRetry || toc(t0) < 0.002
    k = k + 1;
    hdr = freshRead(fid, 2, 'double');
    if numel(hdr) < 2, continue; end            % short read (file being rebuilt): retry
    seq = hdr(1); n = hdr(2);
    if seq == 0 && n <= 0
        ok = true;          % nothing published yet: a valid empty frame
        return
    end
    if seq <= 0 || n <= 0 || n > (L.CAP - L.HEAD - L.TAIL) || n ~= fix(n), continue; end
    rec = freshRead(fid, L.HEAD + n + L.TAIL, 'uint8=>uint8');
    if numel(rec) < L.HEAD + n + L.TAIL, continue; end
    if ~isequal(rec(1:8), rec(L.HEAD+n+1:end)) || typecast(rec(1:8), 'double') ~= seq, continue; end
    if ~isequal(freshRead(fid, 1, 'double'), seq), continue; end   % a write began meanwhile: retry
    try
        frame = getArrayFromByteStream(rec(L.HEAD+1:L.HEAD+n));
        ok = true;
        return
    catch
        % payload not yet consistent; retry
    end
end
end

function v = freshRead(fid, n, precision)
% Read from the start of the file as it is NOW. A seek straight back to the
% start lands inside the C library's read buffer and returns the bytes read
% last time, not what the writer has written since; seeking to the end first
% leaves the buffer (tested: without it 1999 of 2000 reads were stale).
fseek(fid, 0, 'eof');
fseek(fid, 0, 'bof');
v = fread(fid, n, precision);
end
