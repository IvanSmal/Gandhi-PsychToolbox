function L = sceneLayout()
%SCENELAYOUT Shape of the shared scene slot.
%
%   The slot holds ONE serialised frame:
%
%       [ seq | nBytes | payload bytes ... | seq ]
%
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
%   record is written with ONE assignment sized to the payload, so a reader
%   catching a partial forward write sees a stale tail and retries.
%
%   Measured: encode 5 us, write 48 us (typical frame) to 91 us (1000-dot
%   field), read+decode 30-70 us. The UDP command stream it replaced cost
%   3220 us per iteration.
L.VERSION  = 2;
L.SEQ      = 1;      % sequence number, head
L.NBYTES   = 2;      % payload length in bytes
L.DATA0    = 3;      % first payload element
L.CAP      = 262144; % slot capacity in doubles (2 MB file, ~256 KB payload)
end
