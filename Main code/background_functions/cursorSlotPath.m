function p = cursorSlotPath(id)
%CURSORSLOTPATH Shared-memory slot for one UDP cursor's position (millimetres).
%   One slot per cursor id (1..5), same seqlock format as mousePath
%   (sceneOpen/sceneWrite/sceneRead). GraphicsHandler is the only writer: it
%   owns each UDP cursor's socket and every frame publishes
%   struct('on',1,'x',mmx,'y',mmy,'t',getsecs) -- the position in MILLIMETRES,
%   after the cursor's gain/offset. cursorinfo in the task process reads this
%   slot instead of binding the port, so exactly one process ever owns a given
%   UDP socket. The slot is created on first publish, so analog-only or
%   eye-only sessions never touch it.
if nargin < 1 || isempty(id), id = 1; end
name = sprintf('gandhi_cursor%d.bin', id);
if isfolder('/dev/shm')
    p = fullfile('/dev/shm', name);
else
    p = fullfile(tempdir, name);
end
end
