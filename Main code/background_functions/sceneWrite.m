function sceneWrite(m, seq, frame)
%SCENEWRITE Publish a frame into the shared slot with one contiguous write.
L = sceneLayout();
b = getByteStreamFromArray(frame);
n = numel(b);
if n > (L.CAP - 3)
    error('sceneWrite:tooBig', ...
        'frame is %d bytes, slot holds %d. Raise sceneLayout CAP.', n, L.CAP-3);
end
rec = zeros(n+3,1);
rec(L.SEQ)    = seq;
rec(L.NBYTES) = n;
rec(L.DATA0:L.DATA0+n-1) = double(b(:));
rec(end)      = seq;
m.Data.s(1:n+3) = rec;      % single assignment, sized to the payload
end
