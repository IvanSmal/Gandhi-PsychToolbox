function p = scenePath()
%SCENEPATH Location of the shared scene slot.
%   Prefers /dev/shm (tmpfs: RAM-backed, never hits disk). Falls back to the
%   system temp dir elsewhere. Both the state machine (writer) and
%   GraphicsHandler (reader) resolve the same path this way, so neither
%   needs it configured.
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_scene.bin';
else
    p = fullfile(tempdir, 'gandhi_scene.bin');
end
end
