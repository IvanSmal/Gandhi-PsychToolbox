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
        function obj=eyeinfo(app)
            obj.xgain=app.xgain.Value;
            obj.ygain=app.ygain.Value;
            
            obj.xoffset=app.xoffset.Value;
            obj.yoffset=app.yoffset.Value;
        end

        function obj = eyeCalib(obj,mh,app,tp)
            chidx=xippmex('elec','analog');
            if nargin >3
                TargPos=tp;
            elseif nargin == 3
                TPmatrix=[0 0 20 20;
                    mh.screenXpixels/2-10 0 mh.screenXpixels/2+10 20;
                    mh.screenXpixels-20 0 mh.screenXpixels 20;
                    mh.screenXpixels-20 mh.screenYpixels/2-10 mh.screenXpixels mh.screenYpixels/2+10;
                    mh.screenXpixels-20 mh.screenYpixels-20 mh.screenXpixels mh.screenYpixels;
                    mh.screenXpixels/2-10 mh.screenYpixels-20 mh.screenXpixels/2+10 mh.screenYpixels;
                    0 mh.screenYpixels-20 20 mh.screenYpixels;
                    0 mh.screenYpixels/2-10 20 mh.screenYpixels/2+10];

                TPmatrix=TPmatrix/1.2;
                TPshift=150;
                TPmatrix=TPmatrix+TPshift;
                TPmatrix=round(TPmatrix);
                
                TargPos=TPmatrix;
            else
                TargPos=[0 0 20 20;
                    100 100 120 120;
                    200 200 220 220];
            end

            for i=1:size(TargPos,1)
                Screen2('FillRect', mh, [1 1 1], TargPos(i,:));
                Screen2('Flip', mh,[],[],2);
                KbWait([], 2);
 
                xpos(i)=xippmex('cont', chidx(3),1,'1ksps'); %set which eye channels are here
                ypos(i)=xippmex('cont', chidx(4),1,'1ksps');
            end

            xtarg=mean(TargPos(:,[1,3]),2);
            ytarg=mean(TargPos(:,[2,4]),2);

            xvals=polyfit(xpos,xtarg,1);
            yvals=polyfit(ypos,ytarg,1);

            obj.xgain=round(xvals(1),2);
            app.xgain.Value=obj.xgain;

            obj.ygain=round(yvals(1));
            app.ygain.Value=obj.ygain;
            
            obj.xoffset=round(xvals(2));
            app.xoffset.Value=obj.xoffset;

            obj.yoffset=round(yvals(2));
            app.yoffset.Value=obj.yoffset;
            return %idk why this is needed
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

