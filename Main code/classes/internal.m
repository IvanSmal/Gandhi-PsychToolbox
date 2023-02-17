classdef internal < handle
    %INTERNAL Summary of this class goes here
    %   Detailed explanation goes here

    properties
        %% trial properties to pick from. This is user-defined parameters  
        intervals
        targets % database of targets to use in tasks


        % screen properties (do these need to be saved?)
        screens
        window_main
        window_monitor
        windowRect
        monitor_rect
        screenXpixels
        screenYpixels
        width
        height
        xCenter
        yCenter
        texture_main
        texture_monitor
        movie
        tex
        
        %trial metadata properties (can these be combined?)
        trial = trial;
        runtrial 
        trialstarted = 0
        trialnumpersistent=0;
        tlogic

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
        targettime

        % trialtypes logic table
        ttypeslogic
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
            out = strcmp(state, obj.activestatename) && (getsecs < obj.activestatetime + obj.trialint(int));            
        end

        function out=checkeye(obj,targ)
            howfareye=obj.trialtarg(targ,'getpos','center')-obj.eye.geteye;
            hypoteye=hypot(howfareye(1),howfareye(2));
            out=obj.trial.targets.(targ).window>hypoteye;
        end
        
        function stoptrial(obj,success)
            obj.setstate('stop')
            obj.trialstarted = 0;
            obj.runtrial = 0;
            obj.trial.success=success;
        end

        function getmovie(obj, moviepath,varargin)
            obj.movie=Screen('OpenMovie',obj.window_main,moviepath,varargin{:});
        end
        %% methods from old "experiment" structure
        function addtarg(e,name,varargin)
            outcells={'name', name, varargin{:}};
            e.targets.(name)=target(outcells{:});            
        end

        function addint(e,name,dur, prob)
            if nargin ==3
                e.intervals.(name)=interval(name, dur);
            else
                e.intervals.(name)=interval(name, dur, prob);  
            end
        end

        function out=getint(e,name)
            out=e.intervals.(name).getint;         
        end

        function out=trialint(e,name)
            out=e.trial.intervals.(name);         
        end
        
        function out=trialtarg(obj,name,arg,varargin)
            out=obj.trial.targets.(name).(arg)(obj,varargin{:});         
        end

        function set(e,a,b)                                                 %general set function
            for i=length(e)
                e(i).(a)=b;
            end
        end

        function adddata(e,d)                                               %dump data in
            e.trial(e.trialnum).data=d;
        end
      
        function out=gettarg(obj,targname)
            temptarg=obj.targets.(targname);
            tempprops=properties(temptarg);
            for i=1:numel(tempprops)
                numvals=size(temptarg.(tempprops{i}),1);
                if numvals>0
                    randidx=randi(numvals);
                    temptarg.(tempprops{i})=temptarg.(tempprops{i})(randidx,:);
                end
            end
            if ~isempty(temptarg.image)
                Screen('Close')
                temptarg.texture=Screen('MakeTexture', obj.window_main,temptarg.image{1});
                Screen('MakeTexture', obj.window_monitor,temptarg.image{1});
            end
            out=temptarg;
        end
    end
end

