classdef target% < handle
    properties
        name
        size = [0 0 5 5]
        position = [0 0; 10 10; 20 20]
        final_position
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
                targ.final_position=temppos;

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
                    targ.final_position=temppos;
                else
                    xf=@(t,x) eval(targ.custompath_x);
                    yf=@(t,y) eval(targ.custompath_y);

                    tempx=xf(tim,targ.position(1));
                    tempy=yf(tim,targ.position(2));

                    temppos=[tempx tempy];
                    targ.final_position=temppos;
                end
            end

            if matches(targ.shape,'square',IgnoreCase=true) ||...
                    matches(targ.shape,'circle',IgnoreCase=true)
                out=targ.squarepos(temppos);
            end
        end

        function out=squarepos(targ,temppos)
            hwidth=targ.size(3)-targ.size(1);
            hheight=targ.size(4)-targ.size(2);


            out=[temppos(1)-hwidth,...
                temppos(2)-hheight,...
                temppos(1)+hwidth,...
                temppos(2)+hheight];
        end

        function out=getcolor(t,mh,varargin)
            out=t.color(varargin{:});
        end

        function out=gettexture(t,mh,varargin)
%                 out=Screen('MakeTexture', mh.window_main, t.texture);
            out=t.texture;
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