classdef internal < dynamicprops
    %INTERNAL Summary of this class goes here
    %   Detailed explanation goes here

    properties
        app

        screens
        window_main
        window_monitor
        windowRect
        screenXpixels
        screenYpixels
        width
        height
        xCenter
        yCenter
        runtrial
        eye
        rew = struct('rewon',0);
        trial = trial;
    end

    methods

        function obj=reward(obj,int)
            if obj.rew.rewon==0
                obj.rew.rewstart=getsecs;
                obj.rew.rewon=1;
                obj.rew.int=int;
                obj.rew.started=0;
            end
            rewcheck(obj)
        end
        function obj = rewcheck(obj)
            if obj.rew.rewon==1 &&...
                    getsecs<obj.rew.rewstart+obj.rew.int &&...
                    obj.rew.started==0

                xippmex('digout',4,1);
                obj.rew.started=1;
                beep

            elseif obj.rew.rewon==1 &&...
                    getsecs>obj.rew.rewstart+obj.rew.int

                xippmex('digout',4,0);
                obj.app.insToTxtbox(['reward t: ' num2str(getsecs-obj.rew.rewstart)])
                obj.rew.rewon=0;
            end
        end
    end
end

