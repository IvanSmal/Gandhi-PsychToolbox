function sceneWrite(m, seq, frame)
%SCENEWRITE Publish a frame into the shared slot.
%   A sequence lock: the head first says the slot is being written (-seq),
%   then the length, payload and tail go in, and the head gets seq last.
%   Each step is flushed before the next, so a reader that finds the same
%   positive head before and after its read knows no write overlapped it
%   (see sceneRead).
L = sceneLayout();
b = getByteStreamFromArray(frame);
n = numel(b);
if n > (L.CAP - L.HEAD - L.TAIL)
    error('sceneWrite:tooBig', ...
        'frame is %d bytes, slot holds %d. Raise sceneLayout CAP.', n, L.CAP - L.HEAD - L.TAIL);
end
h = typecast([double(seq) n], 'uint8');      % seq, nBytes
busy = typecast(-double(seq), 'uint8');
fid = m.fid;
fseek(fid, 0, 'bof'); fwrite(fid, busy, 'uint8');                     % 1. being written
fseek(fid, 8, 'bof'); fwrite(fid, [h(9:16).'; b(:); h(1:8).'], 'uint8');   % 2. length, payload, tail
fseek(fid, 0, 'bof'); fwrite(fid, h(1:8), 'uint8');                   % 3. done: head = seq
fseek(fid, 0, 'bof');     % each seek flushes MATLAB's buffer, so the steps reach readers in order
end
