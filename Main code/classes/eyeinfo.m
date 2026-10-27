classdef eyeinfo < handle
    % Sets the properties for the position of the eye, including xgain and
    % ygain. Running obj=Eye will start the calibration process

    properties
        x = 0
        y = 0

        xgain (1,1) double = 1
        ygain (1,1) double = 1
        xoffset (1,1) double = 1
        yoffset (1,1) double = 1

        xchan = []           % analog channel id for eye x ([] -> first analog channel; legacy default)
        ychan = []           % analog channel id for eye y ([] -> second analog channel)

        mousemap = []        % reader handle for the mouse-mode shared slot (lazy)
    end

    properties (Access = private)
        % The eye is read on every pass of the trial loop, so the channels to
        % read are worked out once (see readxy), not with an xippmex call each time.
        chanKey = {}         % {xchan, ychan} the cache below was made from
        chanRead = []        % channels to read, ascending
        chanRows = [1 2]     % rows of that read holding x and y
    end

    methods
        function obj=eyeinfo
            % eye calibration is machine-written state, not hand config.
            % MHost2 rewrites the file between trials while GraphicsHandler
            % rebuilds this object every idle frame, so a read can land on a
            % save in progress. Each retry re-reads the FILE: asking the same
            % parsed copy again can never succeed.
            for attempt = 1:50
                try
                    ini = rigIni('state');
                    obj.xgain=ini.GetValues('eye calibration','xgain');
                    obj.ygain=ini.GetValues('eye calibration','ygain');

                    % true_center=ini.GetValues('for deg2pix','true center');

                    obj.xoffset=ini.GetValues('eye calibration','xoffset');
                    obj.yoffset=ini.GetValues('eye calibration','yoffset');
                    % optional eye channel assignment (File > Cursor Assignment). Absent
                    % on a legacy rig -> stays [] and geteye uses the first two analog.
                    try, obj.xchan=ini.GetValues('eye calibration','xchan'); catch, end
                    try, obj.ychan=ini.GetValues('eye calibration','ychan'); catch, end
                    return
                catch readerr
                    pause(0.01)
                end
            end
            % still failing after ~0.5 s of fresh reads: the file itself is bad
            if strcmp(readerr.identifier, 'rigIni:readFailed')
                rethrow(readerr)   % missing/unreadable file: same error as before
            end
            inipath=which('ScreenParams.ini');
            waitfor(msgbox(['Something is wrong with the eye calibration parameters. Review the text file for strange inputs under the [eye calibration] section and restart the app. Path to file: ' inipath]))
            quit
        end

        function obj = set(obj,prop,val)
            obj.(prop)=val;
        end

        function obj = seteyeoff(obj,xg,yg,xo,yo)
            obj.xgain=xg;
            obj.ygain=yg;
            obj.xoffset=xo;
            obj.yoffset=yo;
        end

        function obj = seteyepos(obj,x,y)
            obj.x=x;
            obj.y=y;
        end

        function m = getmouseslot(obj)
            % Lazy-open the mouse-mode slot as a reader, but only if it exists
            % (it is created only once mouse mode has been used). Returns [] when
            % there is no slot, so normal operation never reads it.
            if isempty(obj.mousemap)
                p = mousePath();
                if isfile(p)
                    try, obj.mousemap = sceneOpen(false, p); catch, obj.mousemap = []; end
                end
            end
            m = obj.mousemap;
        end

        function out = mousepos(obj)
            % [x y] display pixels if mouse mode is on AND aimed at the eye,
            % else []. Shared with cursorinfo via readMouseSlot; the mouse-mode
            % target ('eye' or 'cursorN') decides which input the mouse drives.
            out = readMouseSlot('eye');
        end

        function out = geteye(obj,t)
            mp = obj.mousepos();
            if ~isempty(mp)
                % Mouse mode: the mouse IS the gaze point, already in display
                % pixels, so no gain/offset and no eye-tracker read.
                seteyepos(obj, mp(1), mp(2));
                if nargin == 1, out = mp; else, out = [mp(1); mp(2)]; end
                return
            end
            if nargin == 1
                v = readxy(obj, 1);
                xeye=v(1,:)*obj.xgain+obj.xoffset;
                yeye=v(2,:)*obj.ygain+obj.yoffset;
                seteyepos(obj,xeye,yeye);
                out=[xeye,yeye];
            else
                v = readxy(obj, t);
                xeye=v(1,:)*obj.xgain+obj.xoffset;
                yeye=v(2,:)*obj.ygain+obj.yoffset;
                seteyepos(obj,xeye(end),yeye(end));
                out=[xeye;yeye];
            end
            out=round(out);
        end


        function out = getraweye(obj)
            mp = obj.mousepos();
            if ~isempty(mp)
                out = [mp(1), mp(2)];   % mouse mode: raw == mapped (no calibration)
                return
            end
            v = readxy(obj, 1);
            out=[v(1,:),v(2,:)];
        end
    end

    methods (Access = private)
        function v = readxy(obj, n)
            % The newest N samples of the eye's x and y channels, rows [x; y],
            % in ONE xippmex read (both from the same samples). Channels: the
            % chosen ones (xchan / ychan), else the first two analog inputs.
            key = {obj.xchan, obj.ychan};
            if ~isequal(key, obj.chanKey) || isempty(obj.chanRead)
                xc=obj.xchan; yc=obj.ychan;
                if isempty(xc) || isempty(yc)
                    chidx=xippmex('elec','analog');
                    if isempty(xc), xc=chidx(1); end   % ([] -> legacy first two analog)
                    if isempty(yc), yc=chidx(2); end
                end
                [obj.chanRead, ~, obj.chanRows] = unique([xc yc]);   % ascending; rows come back in that order
                obj.chanKey = key;
            end
            r = xippmex('cont', obj.chanRead, n, '1ksps');
            if size(r, 1) < numel(obj.chanRead), v = zeros(2, 0); return, end   % failed read: empty, as before
            v = r(obj.chanRows, :);
        end
    end
end
