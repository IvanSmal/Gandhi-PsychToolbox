function pos = readMouseSlot(target)
%READMOUSESLOT Mouse-mode position for a given input, or [] if not active.
%   pos = readMouseSlot(target) returns [x y] in DISPLAY pixels when mouse mode
%   is on AND aimed at `target` ('eye' or 'cursor1'..'cursor5'); otherwise [].
%   Shared by eyeinfo.geteye and cursorinfo.getcursor so the File > Mouse Mode
%   toggle (which picks the target) drives whichever input is selected. The
%   slot only exists while mouse mode has been used, so normal reads return [].
%   Legacy slots without a 'target' field are treated as targeting the eye.
    persistent m
    pos = [];
    try
        if isempty(m)
            p = mousePath();
            if ~isfile(p), return; end
            m = sceneOpen(false, p);
        end
        [md, ok] = sceneRead(m);
        if ok && isstruct(md) && isfield(md,'on') && md.on == 1
            tgt = 'eye';
            if isfield(md,'target') && ~isempty(md.target), tgt = md.target; end
            if strcmpi(tgt, target)
                pos = round([md.x md.y]);
            end
        end
    catch
        m = [];   % slot went away (e.g. reboot cleared /dev/shm): re-open next call
    end
end
