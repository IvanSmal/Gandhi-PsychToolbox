function p = mousePath()
%MOUSEPATH Shared-memory slot for "mouse mode" (simulated eye position).
%   Same seqlock format as the scene slot (sceneOpen/sceneWrite/sceneRead).
%   GraphicsHandler is the only writer: while mouse mode is on it publishes
%   struct('on',1,'x',px,'y',py) each frame, where (px,py) is the mouse in the
%   monitor window mapped to DISPLAY pixels. eyeinfo.geteye reads it, so both
%   MonkeyHost (checkeye) and GraphicsHandler (the eye dot) follow the mouse.
%   When mouse mode is off GraphicsHandler publishes struct('on',0,...) and the
%   eye object falls back to the real eye tracker. The slot is created only
%   once mouse mode has been used, so normal sessions never touch it.
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_mouse.bin';
else
    p = fullfile(tempdir, 'gandhi_mouse.bin');
end
end
