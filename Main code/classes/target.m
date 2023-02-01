classdef target% < handle
    properties
        name
        size = [0 0 50 50]
        position = [0 0; 10 10; 20 20]
        twindow = 100;
        color = [1 0 0]
        shape = 'square'
        speed = 0
        direction = 90;
        custompath_x
        custompath_y
        texture
    end
    methods
        function t=target(varargin)
            if nargin ==0
                t.name='T_example';
            else
                for i=1:2:length(varargin)
                    t.(varargin{i})=varargin{i+1};
                end
            end
        end
        
        function addpos(t,pos)
            t.position=[t.position; pos];
        end

        function out = getpos(targ,mh, varargin)
            hwidth=targ.size(3)-targ.size(1);
            hheight=targ.size(4)-targ.size(2);
            if targ.speed==0 && isempty(targ.custompath_x)

                temppos=targ.position;

            else
                if nargin == 2
                    curstate=mh.activestatename;
                    tim=getsecs-mh.trial.state.(curstate).time;
                    mh.targettime=mh.trial.state.(curstate).time;
                else
                    try 
                        curstate = mh.trial.state.(varargin{:}).time;
                        tim=getsecs-mh.trial.state.(curstate).time;
                    catch
                        tim=getsecs-mh.targettime;
                    end
                end

                if isempty(targ.custompath_x)
                    xyadd=[targ.speed*cosd(targ.direction), targ.speed*sind(targ.direction)];
                    tempx=targ.position(1)+xyadd(1)*tim;
                    tempy=targ.position(2)+xyadd(2)*tim;

                    temppos=[tempx tempy];
                else
                    disp('here')
                    xf=@(t,x) eval(targ.custompath_x);
                    yf=@(t,y) eval(targ.custompath_y);
                    
                    tempx=xf(tim,targ.position(1));
                    tempy=yf(tim,targ.position(2));

                    temppos=[tempx tempy];
                end
            end
            
            if matches(targ.shape,'square',IgnoreCase=true)
                out=squarepos(temppos);
            end
        end

        function out=squarepos(targ,temppos)
            hwidth=targ.size(3)-targ.size(1);
            hheight=targ.size(4)-targ.size(2);
            if targ.speed==0 && isempty(targ.custompath_x)

                out=[targ.position(1)-hwidth,...
                    targ.position(2)-hheight,...
                    targ.position(1)+hwidth,...
                    targ.position(2)+hheight];

            else
                if nargin == 2
                    curstate=mh.activestatename;
                    tim=getsecs-mh.trial.state.(curstate).time;
                    mh.targettime=mh.trial.state.(curstate).time;
                else
                    try 
                        curstate = mh.trial.state.(varargin{:}).time;
                        tim=getsecs-mh.trial.state.(curstate).time;
                    catch
                        tim=getsecs-mh.targettime;
                    end
                end

                if isempty(targ.custompath_x)
                    xyadd=[targ.speed*cosd(targ.direction), targ.speed*sind(targ.direction)];
                    tempx=targ.position(1)+xyadd(1)*tim;
                    tempy=targ.position(2)+xyadd(2)*tim;
                else
                    disp('here')
                    xf=@(t,x) eval(targ.custompath_x);
                    yf=@(t,y) eval(targ.custompath_y);
                    
                    tempx=xf(tim,targ.position(1));
                    tempy=yf(tim,targ.position(2));
                end


                out=[tempx-hwidth,...
                    tempy-hheight,...
                    tempx+hwidth,...
                    tempy+hheight];
            end
        end

        function out=getcolor(t,mh,varargin)
            out=t.color(varargin{:});
        end

        function out=targpos(t, idx)
            if nargin ==1
                out=t.position;
            else
                out=t.position(idx,:);
            end
        end

        function out=randpos(t,varargin)
            if t.speed==0
                if nargin ==1
                    idx=randi(size(t.position,1));
                    out=t.position(idx,:);
                elseif strcmp(varargin{1},'square')
                    hwidth=t.size(3)-t.size(1);
                    hheight=t.size(4)-t.size(2);
                    idx=randi(size(t.position,1));
                    out=[t.position(idx,1)-hwidth,...
                        t.position(idx,2)-hheight,...
                        t.position(idx,1)+hwidth,...
                        t.position(idx,2)+hheight];
                end
            else
                if nargin==1
                    idx=randi(size(t.position,1));
                    out=t.position(idx,:);
                elseif strcmp(varargin{1},'square')
                    hwidth=t.size(3)-t.size(1);
                    hheight=t.size(4)-t.size(2);
                    idx=randi(size(t.position,1));
                    out=[t.position(idx,1)-hwidth,...
                        t.position(idx,2)-hheight,...
                        t.position(idx,1)+hwidth,...
                        t.position(idx,2)+hheight];
                end
            end
        end

        function out=randir(t, varargin)
            out=t.direction(randi(length(t.direction)));
        end
    end
end