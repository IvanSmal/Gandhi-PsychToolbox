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
            
            obj.xoffset=ini.GetValues('eye calibration','xoffset');
            obj.yoffset=ini.GetValues('eye calibration','yoffset');
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
                xeye=xippmex('cont', chidx(3),1,'1ksps')*...
                    obj.xgain+obj.xoffset;
                yeye=xippmex('cont', chidx(4),1,'1ksps')*...
                    obj.ygain+obj.yoffset;
                seteyepos(obj,xeye,yeye);
                out=[xeye,yeye];
            else
                xeye=xippmex('cont', chidx(3),t,'1ksps')*...
                    obj.xgain+obj.xoffset;
                yeye=xippmex('cont', chidx(4),t,'1ksps')*...
                    obj.ygain+obj.yoffset;
                seteyepos(obj,xeye(end),yeye(end));
                out=[xeye;yeye];
            end
        end
    end
end

