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
    end

    methods
        function obj=eyeinfo
            ini = IniConfig();
            ini.ReadFile('inis/ScreenParams.ini');

            obj.xgain=ini.GetValues('eye calibration','xgain');
            obj.ygain=ini.GetValues('eye calibration','ygain');

            % true_center=ini.GetValues('for deg2pix','true center');

            obj.xoffset=deg2pix([ini.GetValues('eye calibration','xoffset') nan],'cart');
            obj.yoffset=deg2pix([nan ini.GetValues('eye calibration','yoffset')],'cart');
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

        function out = geteye(obj,t)
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
            chidx=xippmex('elec','analog');

            xeye=xippmex('cont', chidx(1),1,'1ksps');
            yeye=xippmex('cont', chidx(2),1,'1ksps');
            out=[xeye,yeye];
        end
    end
end

