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
        trial_function

        %diode properties
        diode_pos = [0,1300 ,50, 1350];
        diode_on = 0;
        diode_color= [1,1,1];

        % for eye movement detection
        eye % maybe move to "experiment"
        targhistory=zeros(4,10);

        rew = struct('rewon',0);

        % For statechanges and diode flips
        activestatetime=[]
        activestatename = 'null';
        targettime
        

        % trialtypes logic table
        ttypeslogic

        %collision stuff
        coltimer=0

        %communicate with graphics
        graphicsport
        graphicssent=0

    end

    methods       
        function endstate(obj)
            obj.graphicssent=1;
        end
        
        function evalgraphics(obj,command)
                writeline(obj.graphicsport,['execute' command],'0.0.0.0',2021)
        end

        function WaitForGraphics(mh)
            mh.graphicssent=0;
            while mh.graphicssent==0                
                str=('writeline(graphicsport,''mh.graphicssent=1;'',''0.0.0.0'',2020);');
                mh.evalgraphics(str);
                com=readline(mh.graphicsport);
                try %this is a dirty way to make sure 'com' is evaluatable
                    eval(com);
                end
            end
        end

        
        function varargout = Screen(mh,varargin)
            if mh.graphicssent==1 || matches(varargin{1},'Flip','IgnoreCase',true)
                str=string();
                for i=1:length(varargin)
                    namecount=1;
                    if matches(class(varargin{i}),'char')
                        if contains(varargin{i},'gr')
                            varval=['' varargin{i} ''];
                        else
                            varval=['''' varargin{i} ''''];
                        end
                    elseif isnumeric(varargin{i})
                        varval=mat2str(varargin{i});
                    else
                        varval=strcat('''',string(inputname(namecount)),'''');
                        namecount=namecount+1;                        
                    end
                    str=strcat(str, 'args{',num2str(i), '}=', varval, ';');
                end
                if matches(varargin{1},'DrawTexture')
                    varval=replace(varargin{3},'.texture','.monitortexture');
                    str=strcat(str, 'additionalinfo{1}=', varval, ';');
                end

                if nargout>0
                    for i=1:nargout
                        str=strcat(str, 'outs{',num2str(i), '}=', '''a',num2str(i), ''';');
                    end
                end

                writeline(mh.graphicsport,str,'0.0.0.0',2021); %actually send the data

                
                if nargout>0
                    commands=readline(mh.graphicsport);
                    eval(commands)
                    for i=1:nargout
                        varargout{i}=eval(['a' num2str(i)]);
                    end
                end
                flush(mh.graphicsport)
            end
        end

        function obj=reward(obj,int)
            if obj.rew.rewon==0
                obj.rew.rewstart=getsecs;
                obj.rew.rewon=1;
                obj.rew.int=int;
            end
        end

        function obj = rewcheck(obj,app)
            if obj.rew.rewon==1 &&...
                    getsecs<obj.rew.rewstart+obj.rew.int

                xippmex('digout',[3,4],[1,1]);

            elseif obj.rew.rewon==1 &&...
                    getsecs>obj.rew.rewstart+obj.rew.int
                xippmex('digout',[3,4],[0,0]);
                app.insToTxtbox(['reward t: ' num2str(getsecs-obj.rew.rewstart)]);
                obj.rew.rewon=0;
            end
        end

        function setstate(mh, name, count)
            if ~isfield(mh.trial.state,name)
                mh.trial.state.(name).count=-100;
            end
            if nargin < 3
                count=length(mh.trial.state);
            end

            mh.trial.state.(name).time=getsecs;

            mh.trial.state.(name).count=count;

            if ~strcmp(mh.activestatename,name)
                mh.activestatetime = mh.trial.state.(name).time;
                mh.activestatename = name;
            end
            
            mh.evalgraphics(['gr.activestatename =' '''' mh.activestatename '''' ';'])

            mh.diodeflip
        end

        function out = checkstate(obj,state)
            out = strcmp(state, obj.activestatename);
        end

        function diodeflip(mh)
            if ~mh.diode_on
                mh.diode_color=[1;1;1];
                mh.diode_on = 1;
            else
                mh.diode_color=[0;0;0];
                mh.diode_on = 0;
            end
            % mh.Screen('FillRect', mh, mh.diode_color, mh.diode_pos);
            mh.evalgraphics(['gr.diode_color=' mat2str(mh.diode_color) ';'])
            mh.WaitForGraphics;
        end

        function out = checkint(mh, state, int)
            out = strcmp(state, mh.activestatename) && (getsecs < mh.activestatetime + mh.trialint(int));
        end

        function out=checkeye(obj,targ)
            targpos=obj.trialtarg(targ,'getpos','center');
            howfareye=targpos-obj.eye.geteye;
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

        function out=targcollisioncheck(obj,t1,t2)
            if obj.coltimer==0 || obj.coltimer==100
                t1pos=obj.trialtarg(t1,'getpos');
                t2pos=obj.trialtarg(t2,'getpos');

                t1x=t1pos(1):t1pos(3);
                t2x=t2pos(1):t2pos(3);

                t1y=t1pos(2):t1pos(4);
                t2y=t2pos(2):t2pos(4);

                if any(ismember(t1x,t2x)) && any(ismember(t1y,t2y))
                    out=1;
                    obj.coltimer=obj.coltimer+1;
                else
                    out=0;
                    if obj.coltimer==100
                        obj.coltimer=0;
                    end
                end

            elseif obj.coltimer==100
                obj.coltimer=0;
                out=0;
            else
                obj.coltimer=obj.coltimer+1;
                out=0;
            end
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

        function out=getint(mh,name)
            out=mh.intervals.(name).getint(1);
            mh.trial.insert('intervals',out);
        end

        function out=trialint(mh,name)% internal
            out=mh.trial.intervals.(name).duration;
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

        function out=gettarg(mh,targname)
            temptarg=mh.targets.(targname);
            tempprops=properties(temptarg);
            for i=1:numel(tempprops)
                numvals=size(temptarg.(tempprops{i}),1);
                if numvals>0
                    randidx=randi(numvals);
                    temptarg.(tempprops{i})=temptarg.(tempprops{i})(randidx,:);
                end
            end
            if ~isempty(temptarg.image)
                %% create a set of commands to send to graphics handler
                Str1=strcat('gr.target.',targname,'.image=','imread(''',temptarg.image, ''');');
                Str2=strcat('gr.target.',targname,'.texture=');
                Str3=strcat('Screen(''MakeTexture'',gr.window_main,gr.target.',...
                    targname,'.image);');
                Str4=strcat('gr.target.',targname,'.monitortexture=');
                Str5=strcat('Screen(''MakeTexture'',gr.window_monitor,gr.target.',...
                    targname,'.image);');
                MasterString=strcat(Str1,Str2,Str3,Str4,Str5);
                mh.evalgraphics(MasterString)
            end
            mh.trial.insert('targets',temptarg);
            out=temptarg;
        end
    end
end

