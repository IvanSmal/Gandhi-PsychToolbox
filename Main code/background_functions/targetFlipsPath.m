function p = targetFlipsPath()
%TARGETFLIPSPATH Shared-memory slot for the display's recent target positions.
%   GraphicsHandler publishes the last second of display flips here, about
%   every 100 ms during trials: each flip's counter and onset time (GetSecs),
%   and the targets and 'Tag'ged items it showed with their centres in display
%   pixels. TrellisScope reads it to plot target positions over time, putting
%   the onsets on the NIP clock itself. Same seqlock format as the scene slot.
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_target_flips.bin';
else
    p = fullfile(tempdir, 'gandhi_target_flips.bin');
end
end
