function p = stateOnsetPath()
%STATEONSETPATH Shared-memory slot for live state onsets (name + NIP tick).
%   setstate publishes a rolling ring of the most recent state onsets here, each
%   with the NIP tick (xippmex('time')) captured at the transition. Live monitors
%   (TrellisScope) drain it to mark state onsets with PRECISE NIP timestamps --
%   the same clock as the eye/spike data they read, so alignment is sub-ms. This
%   is independent of the digout event-code markers, which timestamp state onsets
%   in the neural RECORDING (for offline analysis) but are not broadcast to
%   passive xippmex clients. Same seqlock format as the scene slot.
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_state_onsets.bin';
else
    p = fullfile(tempdir, 'gandhi_state_onsets.bin');
end
end
