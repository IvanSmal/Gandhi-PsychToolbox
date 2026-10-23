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
            chidx=xippmex('elec','analog');
            xc=obj.xchan; if isempty(xc), xc=chidx(1); end   % selectable eye channels
            yc=obj.ychan; if isempty(yc), yc=chidx(2); end   % ([] -> legacy first two analog)
            if nargin == 1
                xeye=xippmex('cont', xc,1,'1ksps')*...
                    obj.xgain+obj.xoffset;
                yeye=xippmex('cont', yc,1,'1ksps')*...
                    obj.ygain+obj.yoffset;
                seteyepos(obj,xeye,yeye);
                out=[xeye,yeye];
            else
                xeye=xippmex('cont', xc,t,'1ksps')*...
                    obj.xgain+obj.xoffset;
                yeye=xippmex('cont', yc,t,'1ksps')*...
                    obj.ygain+obj.yoffset;
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
            chidx=xippmex('elec','analog');
            xc=obj.xchan; if isempty(xc), xc=chidx(1); end
            yc=obj.ychan; if isempty(yc), yc=chidx(2); end
            xeye=xippmex('cont', xc,1,'1ksps');
            yeye=xippmex('cont', yc,1,'1ksps');
            out=[xeye,yeye];
        end
    end
end
