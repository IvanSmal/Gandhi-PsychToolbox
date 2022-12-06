classdef eye
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
        function obj=eye(app)
            obj.xgain=app.xgain.Value;
            obj.ygain=app.ygain.Value;
            
            obj.xoffset=app.xoffset.Value;
            obj.yoffset=app.yoffset.Value;
        end

        function obj = eyeCalib(obj,w,app,tp)
            chidx=xippmex('elec','analog');
            if nargin >3
                TargPos=tp;
            elseif nargin == 3
                TargPos=[0 0 20 20;
                    w.screenXpixels/2-10 0 w.screenXpixels/2+10 20;
                    w.screenXpixels-20 0 w.screenXpixels 20;
                    w.screenXpixels-20 w.screenYpixels/2-10 w.screenXpixels w.screenYpixels/2+10;
                    w.screenXpixels-20 w.screenYpixels-20 w.screenXpixels w.screenYpixels;
                    w.screenXpixels/2-10 w.screenYpixels-20 w.screenXpixels/2+10 w.screenYpixels;
                    0 w.screenYpixels-20 20 w.screenYpixels;
                    0 w.screenYpixels/2-10 20 w.screenYpixels/2+10];
            else
                TargPos=[0 0 20 20;
                    100 100 120 120;
                    200 200 220 220];
            end

            for i=1:size(TargPos,1)
                Screen('FillRect', w.window_main, [1 1 1], TargPos(i,:));
                Screen('Flip', w.window_main);
                KbWait([], 2);
 
                xpos(i)=xippmex('cont', chidx(1),1,'1ksps');
                ypos(i)=xippmex('cont', chidx(2),1,'1ksps');
            end

            xtarg=mean(TargPos(:,[1,3]),2);
            ytarg=mean(TargPos(:,[2,4]),2);

            xvals=polyfit(xpos,xtarg,1);
            yvals=polyfit(ypos,ytarg,1);

            obj.xgain=xvals(1);
            app.xgain.Value=xvals(1);

            obj.ygain=yvals(1);
            app.ygain.Value=yvals(1);
            
            obj.xoffset=xvals(2);
            app.xoffset.Value=xvals(2);

            obj.yoffset=yvals(2);
            app.yoffset.Value=yvals(2);
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
                seteyepos(obj,xeye,yeye);
                out=[xeye;yeye];
            end
        end
    end
end

