classdef sceneSlot < handle
    %SCENESLOT An open shared slot: its file, kept open for reading or writing.
    %   Made by sceneOpen and used by sceneRead / sceneWrite, which read and
    %   write the file in /dev/shm directly (fread / fwrite) rather than
    %   through memmapfile (see sceneLayout). The file is closed when the last
    %   copy of the handle goes away, e.g. when a caller sets its map to [].
    %
    %   The open file is not saved with the object (Transient). Objects that
    %   hold a slot get saved - e.LastParameters is MHost2's whole internal
    %   object - and a copy loaded back carried the live slot's file number:
    %   when MATLAB cleared the copy, its delete closed MHost2's open scene
    %   slot (seen: "Invalid file identifier" on the next START). A loaded
    %   copy now opens its own file the first time it is used.
    properties (SetAccess = private)
        path = ''
        writable = false
    end
    properties (Transient, Access = private)
        fh = -1             % the open file; -1 = not opened (yet) in this copy
    end
    properties (Dependent)
        fid                 % the open file, opened on first use
    end

    methods
        function s = sceneSlot(p, writable)
            s.path = char(p);
            s.writable = logical(writable);
            s.open();
        end

        function v = get.fid(s)
            if s.fh < 0, s.open(); end
            v = s.fh;
        end

        function delete(s)
            if s.fh >= 0
                try, fclose(s.fh); catch, end
                s.fh = -1;
            end
        end
    end

    methods (Access = private)
        function open(s)
            if s.writable, perm = 'r+'; else, perm = 'r'; end
            s.fh = fopen(s.path, perm);
            if s.fh < 0
                error('sceneSlot:open', 'cannot open shared slot "%s"', s.path);
            end
        end
    end
end
