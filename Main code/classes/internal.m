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
        autocalibrationmatrix=[];
        screenparams
        
        rew = struct('rewon',0);

        % For statechanges and diode flips
        activestatetime=[]
        activestatename = 'null';
        targettime


        % trialtypes logic table
        ttypeslogic
        failcounter

        %collision stuff
        coltimer=0
        eccentricity_gain;

        %communicate with graphics
        graphicsport
        graphicssent=0
        cachedout = 'default'
        graphicscommandbuffer=''; %graphics buffer. move to private later
        lastcommand = 1; %move to private later

        %user definitions
        userdefined;

    end

    properties (Access=private)
        checkeye_counter=[0,0,0]; % grace period of 3 samples for eye to be in
        parpool=backgroundPool;

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
            currentcommand=jsonencode({varargin{[1,3:end]}});
            if ~strcmp(mh.cachedout,currentcommand) %check that it is not sending the same command
                mh.cachedout=currentcommand; %cache current command

                if ~matches(varargin{1},'clearbuffer','IgnoreCase',true) &&...
                        ~matches(varargin{1},'sendtogr','IgnoreCase',true) %check that user is not trying to clear the UDP buffer
                    str=string();
                    for i=1:length(varargin)
                        namecount=1;
                        if matches(class(varargin{i}),'char')
                            if contains(varargin{i},'gr') % if the user calls for graphics then...
                                varval=['' varargin{i} '']; % send "gr" as a call to the gr object
                            else
                                varval=['''' varargin{i} '''']; % otherwise convert to interpretable string
                            end
                        elseif isnumeric(varargin{i}) % if it's a number, make it a string
                            varval=mat2str(varargin{i});
                        else
                            varval=['''',string(inputname(namecount)),''''];
                            namecount=namecount+1;
                        end
                        str=[str, 'args_udp{',num2str(mh.lastcommand), '}=', varval, ';'];
                        mh.lastcommand=mh.lastcommand+1;
                    end

                    if matches(varargin{1},'DrawTexture') %add a texture for monitor window
                        varval=replace(varargin{3},'.texture','.monitortexture');
                        str=[str, 'additionalinfo_udp{1}=', varval, ';']; %put this command into the additional option slot
                    end

                    if nargout>0 %if the user wants an output from psychtoolbox, it goes here
                        for i=1:nargout
                            str=[str, 'outs_udp{',num2str(i), '}=', '''a',num2str(i), ''';'];
                        end
                    end

                    deliminator=['args_udp{',num2str(mh.lastcommand), '}=''endcommand'';'];
                    mh.lastcommand=mh.lastcommand+1;
                    mh.graphicscommandbuffer=[mh.graphicscommandbuffer, str,deliminator];

                    if nargout>0 %get outs. this needs work
                        commands=readline(mh.graphicsport);
                        eval(commands);
                        for i=1:nargout
                            varargout{i}=eval(['a' num2str(i)]);
                        end
                    end
                else %if user calls to clear buffer, clear buffer
                    writeline(mh.graphicsport,'executegr.functionsbuffer=[];','0.0.0.0',2021)
                end
            end
            if matches(varargin{1},'sendtogr','IgnoreCase',true) && ~isempty(mh.graphicscommandbuffer)
                writeline(mh.graphicsport,[mh.graphicscommandbuffer{:}],'0.0.0.0',2021); %actually send the data
                mh.graphicscommandbuffer='';
                mh.lastcommand=1;
                % writeline(mh.graphicsport,'executegr.functionsbuffer=[];','0.0.0.0',2021); %need to figure out how to asynch this
                % parfeval(mh.parpool,@writeline,0,mh.graphicsport,'executegr.functionsbuffer=[];','0.0.0.0',2021);

            end
        end

        function mh = rewcheck(mh,app)
            %reward button check
            [~,~,events]=xippmex('digin');
            if ~isempty(events)
                if sum([events.sma4])>1 && ~mh.rew.rewon
                    mh.reward(app.RewardDuration.Value);
                end
            end
            %reward gui check
            if app.RewardButton.Value
                if ~mh.rew.rewon
                    mh.reward(app.RewardDuration.Value);
                    app.RewardButton.Value=1;
                else
                    app.RewardButton.Value=0;
                end
            end

            if mh.rew.rewon==1 && isnumeric(mh.rew.int)
                duration = mh.rew.int;
            elseif mh.rew.rewon == 1
                duration = mh.rew.int.duration;
            end

            if mh.rew.rewon==1 &&...
                    getsecs<mh.rew.rewstart+duration &&...
                    ~app.StopRewardButton.Value

                xippmex('digout',3,1);

            elseif (mh.rew.rewon==1 &&...
                    getsecs>(mh.rew.rewstart+duration+0.025)) || app.StopRewardButton.Value %the 0.15 is a calibration adjustment
                xippmex('digout',3,0);
                app.insToTxtbox(['reward t: ' num2str(getsecs-mh.rew.rewstart) 's']);
                mh.rew.rewon=0;
                app.StopRewardButton.Value = 0;
                app.RewardButton.Value=0;
                clear sound
            end
            [~,~,events]=xippmex('digin'); %clear digital buffer
        end

        function mh=reward(mh,int)
            if mh.rew.rewon==0
                mh.rew.rewstart=getsecs;
                mh.rew.rewon=1;
                sound(sin(1:1e6),3000);
                mh.rew.int=int;
            end
        end

        function plotwindow(mh,targ, pos)
            windowsize_all=deg2pix([mh.trial.targets.(targ).window mh.trial.targets.(targ).window],'size');
            radius=windowsize_all(3);
            targetlocation = pos;
            centerx=(targetlocation(3)+targetlocation(1))/2;
            centery=(targetlocation(4)+targetlocation(2))/2;
            squarepos=round([centerx-radius centery-radius centerx+radius centery+radius]);
            mh.Screen('FrameOval','monitoronly',[1 1 1],squarepos);
        end

        function setstate(mh, name, count)
            if ~isfield(mh.trial.state,name)
                mh.trial.state.(name).count=0;
            end
            if nargin < 3
                count=mh.trial.state.(name).count+1;
                mh.trial.state.(name).count=count;
            end

            mh.trial.state.(name).time(count)=getsecs;

            if ~strcmp(mh.activestatename,name)
                mh.activestatetime = mh.trial.state.(name).time(end);
                mh.activestatename = name;
            end

            mh.evalgraphics(['gr.activestatename =' '''' mh.activestatename '''' ';'])

            mh.diodeflip;
        end

        function out = checkstate(mh,state)
            out = strcmp(state, mh.activestatename);
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
            % mh.WaitForGraphics;
        end

        function out = checkint(mh, state, int)
            out = strcmp(state, mh.activestatename) && (getsecs < mh.activestatetime + mh.trialint(int));
            if out~=1
                display(mh.activestatetime + mh.trialint(int)-getsecs)
            end
        end

        function out=checkeye(mh,targ,pos)
            if ~exist('pos','var') || isempty(pos)
                targpos=mh.trialtarg(targ,'getpos','center');
                targposSquare=mh.trialtarg(targ,'getpos');
            else
                targetlocation = pos;
                centerx=(targetlocation(3)+targetlocation(1))/2;
                centery=(targetlocation(4)+targetlocation(2))/2;
                targpos=[centerx centery];
                targposSquare=pos;
            end

            degreesfromcenter=pix2deg(targpos,'cart',mh.screenparams);
            targfromcenter=hypot(degreesfromcenter(1),degreesfromcenter(2));
            truegainvalue=targfromcenter*mh.eccentricity_gain;
            truegainpixels=deg2pix([truegainvalue truegainvalue],'size',mh.screenparams);

            windowsize_all=deg2pix([mh.trial.targets.(targ).window mh.trial.targets.(targ).window],'size');
            radius=windowsize_all(3)+truegainpixels(3);
            howfareye=targpos-mh.eye.geteye;
            hypoteye=hypot(howfareye(1),howfareye(2));

            mh.checkeye_counter(end)=radius>hypoteye;
            mh.checkeye_counter=circshift(mh.checkeye_counter,-1);
            out=floor(mean(mh.checkeye_counter));

            if out==1
                 whereseye=mh.eye.getraweye;
                if isempty(mh.autocalibrationmatrix)                   
                    mh.autocalibrationmatrix(1)=targpos(1);
                    mh.autocalibrationmatrix(2)=whereseye(1);
                    mh.autocalibrationmatrix(3)=targpos(2);
                    mh.autocalibrationmatrix(4)=whereseye(2);
                else
                    idx=size(mh.autocalibrationmatrix,1)+1;
                    mh.autocalibrationmatrix(idx,1)=targpos(1);
                    mh.autocalibrationmatrix(idx,2)=whereseye(1);
                    mh.autocalibrationmatrix(idx,3)=targpos(2);
                    mh.autocalibrationmatrix(idx,4)=whereseye(2);
                end
                [~,uidx]=unique(mh.autocalibrationmatrix(:,[1,3]),'last','rows');
                mh.autocalibrationmatrix=mh.autocalibrationmatrix(uidx,:);
            end

            centerx=(targposSquare(3)+targposSquare(1))/2;
            centery=(targposSquare(4)+targposSquare(2))/2;
            squarepos=round([centerx-radius centery-radius centerx+radius centery+radius]);
            mh.Screen('FrameOval','monitoronly',[1 0 0],squarepos);
        end

        function starttrial(mh)
            mh.trialstarted = 1;
            mh.evalgraphics('gr.trialstarted=1;');
        end

        function stoptrial(mh,success)
            mh.setstate('stop')
            mh.trialstarted = 0;
            mh.runtrial = 0;
            mh.trial.success=success;
            mh.evalgraphics('gr.trialstarted=0;');
        end

        function getmovie(mh, moviepath,varargin)
            mh.movie=Screen('OpenMovie',mh.window_main,moviepath,varargin{:});
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
            if ~isnumeric(name)
                out=mh.trial.intervals.(name).duration;
            else
                out=name;
            end
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

