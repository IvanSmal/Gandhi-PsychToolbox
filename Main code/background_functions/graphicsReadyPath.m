function p = graphicsReadyPath()
%GRAPHICSREADYPATH Shared-memory slot GraphicsHandler publishes its readiness into.
%   Same seqlock format as the scene slot (sceneOpen / sceneWrite / sceneRead),
%   opposite direction: the renderer rewrites it on every loop out of a trial,
%   the state machine reads it before each trial (graphicsReady).
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_graphics_ready.bin';
else
    p = fullfile(tempdir, 'gandhi_graphics_ready.bin');
end
end
