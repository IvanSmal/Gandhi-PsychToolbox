function p = renderStatsPath()
%RENDERSTATSPATH Shared-memory slot GraphicsHandler publishes its flip rate into.
%   Same seqlock format as the scene slot (sceneOpen / sceneWrite / sceneRead),
%   opposite direction: the renderer is the only writer, the state machine
%   reads it when it refreshes the misc tab of its GUI.
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_render_stats.bin';
else
    p = fullfile(tempdir, 'gandhi_render_stats.bin');
end
end
