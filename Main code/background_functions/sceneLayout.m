function L = sceneLayout()
%SCENELAYOUT Shape of the shared scene slot.
%
%   The slot holds ONE serialised frame, as bytes:
%
%       [ seq | nBytes | payload bytes ... | seq ]
%
%   seq and nBytes are doubles (8 bytes each); the tail repeats seq.
%   payload is getByteStreamFromArray of a struct:
%       .trialStarted  logical
%       .stateName     char
%       .cmds          cell array of Screen() argument cells
%
%   Any Psychtoolbox Screen call survives this round trip with its real
%   MATLAB types intact - matrices, empties, strings, mixed shapes - so the
%   full Screen API stays available rather than a fixed set of primitives.
%   Nothing is eval'd: getArrayFromByteStream rebuilds the actual values.
%
%   The sequence number is duplicated at BOTH ENDS of the record and the
%   record is written with ONE write sized to the payload, so a reader
%   catching a partial forward write sees a stale tail and retries.
%
%   Version 3 reads and writes the file directly (sceneSlot: fread/fwrite)
%   instead of through memmapfile, which in MATLAB costs far more than the
%   copy itself. Measured in the VM for a typical 2.8 KB frame: write 240 ->
%   33 us, read 214 -> 35 us. Version 2 stored each byte as a double in a
%   2 MB file; the new file size makes sceneOpen rebuild an old slot.
L.VERSION  = 3;
L.HEAD     = 16;       % bytes before the payload: seq, nBytes (doubles)
L.TAIL     = 8;        % bytes after it: seq again
L.CAP      = 4194304;  % slot file size in bytes (4 MB)
end
