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

        mousemap = []        % reader handle for the mouse-mode shared slot (lazy)
    end

    methods
        function obj=eyeinfo
            % eye calibration is machine-written state, not hand config
            ini = rigIni('state');

        try
            obj.xgain=ini.GetValues('eye calibration','xgain');
            obj.ygain=ini.GetValues('eye calibration','ygain');

            % true_center=ini.GetValues('for deg2pix','true center');

            obj.xoffset=ini.GetValues('eye calibration','xoffset');
            obj.yoffset=ini.GetValues('eye calibration','yoffset');
        catch
            failcount=0;
            while failcount < 50
                try
                    obj.xgain=ini.GetValues('eye calibration','xgain');
                    obj.ygain=ini.GetValues('eye calibration','ygain');

                    % true_center=ini.GetValues('for deg2pix','true center');

                    obj.xoffset=ini.GetValues('eye calibration','xoffset');
                    obj.yoffset=ini.GetValues('eye calibration','yoffset');
                    failcount=10000;
                catch
                    failcount = failcount +1;
                end
            end
            if failcount < 100
                inipath=which('ScreenParams.ini');
                waitfor(msgbox(['Something is wrong with the eye calibration parameters. Review the text file for strange inputs under the [eye calibration] section and restart the app. Path to file: ' inipath]))
                quit
            end
        end
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
            % [x y] display pixels if mouse mode is currently on, else []. The
            % slot only reports on==1 while GraphicsHandler is publishing it.
            out = [];
            m = obj.getmouseslot();
            if isempty(m), return; end
            try
                [md, ok] = sceneRead(m);
                if ok && isstruct(md) && isfield(md,'on') && md.on == 1
                    out = round([md.x md.y]);
                end
            catch
            end
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
            if nargin == 1
                xeye=xippmex('cont', chidx(1),1,'1ksps')*...
                    obj.xgain+obj.xoffset;
                yeye=xippmex('cont', chidx(2),1,'1ksps')*...
                    obj.ygain+obj.yoffset;
                seteyepos(obj,xeye,yeye);
                out=[xeye,yeye];
            else
                xeye=xippmex('cont', chidx(1),t,'1ksps')*...
                    obj.xgain+obj.xoffset;
                yeye=xippmex('cont', chidx(2),t,'1ksps')*...
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

            xeye=xippmex('cont', chidx(1),1,'1ksps');
            yeye=xippmex('cont', chidx(2),1,'1ksps');
            out=[xeye,yeye];
        end
    end
end
