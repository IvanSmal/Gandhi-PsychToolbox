function p = scopeMetaPath()
%SCOPEMETAPATH Shared-memory slot MonkeyHost publishes scope metadata into.
%   Same seqlock format as the scene slot (sceneOpen/sceneWrite/sceneRead):
%   MonkeyHost is the only writer (the current trial name, once per trial), and
%   TrellisScope reads it to colour overlaid windows by task type.
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_scope_meta.bin';
else
    p = fullfile(tempdir, 'gandhi_scope_meta.bin');
end
end
