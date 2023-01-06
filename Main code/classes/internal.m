classdef internal < dynamicprops
    %INTERNAL Summary of this class goes here
    %   Detailed explanation goes here

    properties
        app
        
        % screen properties
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
        
        %trial metadata properties (can these be combined?)
        trial = trial;
        runtrial
        trialstarted = 0
        trialnumpersistent=0;

        %diode properties
        diode_pos = [];
        diode_on = 0;
        diode_color= [1,1,1];
        
        % foe eye movement detection
        eye % maybe move to "experiment"

        rew = struct('rewon',0);
        
        % For statechanges and diode flips
        activestatetime=[]
        activestatename = 'null';
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

        function setstate(obj, name, count)
            if ~isfield(obj.trial.state,name)
                obj.trial.state.(name).count=-100;
            end
            if nargin < 3
                count=length(obj.trial.state);
            end

            obj.trial.state.(name).time=getsecs;

            obj.trial.state.(name).count=count;
            
            if ~strcmp(obj.activestatename,name)
                obj.activestatetime = obj.trial.state.(name).time;
                obj.activestatename = name;
            end

            obj.diodeflip

        end

        function out = checkstate(obj,state)
            out = strcmp(state, obj.activestatename);
        end

        function diodeflip(obj)
            if ~obj.diode_on
                obj.diode_color=[1;1;1];
                obj.diode_on = 1;
            else
                obj.diode_color=[0;0;0];
                obj.diode_on = 0;
            end
%             Screen2('FillRect', obj, d_col, obj.diode_pos);
        end

        function out = checkint(obj, state, int)           
            out = strcmp(state, obj.activestatename) && (getsecs < obj.activestatetime + int);
        end
    end
end

