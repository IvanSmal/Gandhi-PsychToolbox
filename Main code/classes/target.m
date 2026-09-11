classdef target %< handle
    properties
        name
        size = [0 0 5 5]
        position = [0 0]
        timestamp=[];
        moving_position=[];
        degreestype='cartesian'
        window = 200;
        color = [1 0 0]
        shape = 'square'
        speed = 0
        direction = 90;
        custompath_x
        custompath_y
        image
        texture
        prevx;
        prevy;
        prevxt=0;
        prevyt=0;
        xdir=1;
        ydir=1;
        xang=1;
        yang=1;
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

            halfWidth=targ.size(3)-targ.size(1);
            halfHeight=targ.size(4)-targ.size(2);
            if targ.speed==0 && isempty(targ.custompath_x)

                tempPos=targ.position;
                degType=targ.degreestype;
                if strcmp(targ.degreestype,'pol') || strcmp(targ.degreestype,'polar') 
                    [tempPos(1),tempPos(2)]=pol2cart(deg2rad(tempPos(1)),tempPos(2));
                    degType='cart';
                end
                mh.trial.targets.(targ.name).moving_position=tempPos;
                pixPos=deg2pix(tempPos,degType,mh.screenparams);
                
            else
                if ~any(matches(varargin(:),'continue',IgnoreCase=true))
                    curState=mh.activestatename;
                    elapsedSec=getsecs-mh.trial.state.(curState).time;
                    mh.targettime=mh.trial.state.(curState).time;
                elseif any(matches(varargin(:),'continue',IgnoreCase=true))
                    try
                        curState = varargin{end};
                        elapsedSec=getsecs-mh.trial.state.(curState).time; 
                    catch
                        elapsedSec=getsecs-mh.targettime;
                        center=varargin(1);
                    end
                end
                
                if isempty(targ.custompath_x)
                    targPos=targ.position;
                    degType=targ.degreestype;
                    if strcmp(targ.degreestype,'pol') || strcmp(targ.degreestype,'polar') 
                        [targPos(1),targPos(2)]=pol2cart(deg2rad(targPos(1)),targPos(2));
                        degType='cart';
                    end

                    xyStep=[targ.speed*cosd(targ.direction), targ.speed*sind(targ.direction)];

                    tempX=targPos(1)+xyStep(1)*elapsedSec;
                    tempY=targPos(2)-xyStep(2)*elapsedSec;

                    tempPos=[tempX tempY];
                    mh.trial.targets.(targ.name).moving_position=...
                        [mh.trial.targets.(targ.name).moving_position; tempPos];
                    mh.trial.targets.(targ.name).timestamp=...
                        [mh.trial.targets.(targ.name).timestamp getsecs];
                    pixPos=deg2pix(tempPos,degType,mh.screenparams);

                else
                    xf=@(mh,t,x) eval(targ.custompath_x);
                    yf=@(mh,t,y) eval(targ.custompath_y);
                    
                    tempX=xf(mh,elapsedSec*targ.speed,targ.position(1));
                    tempY=yf(mh,elapsedSec*targ.speed,targ.position(2));

                    tempPos=[tempX tempY];
                    mh.trial.targets.(targ.name).moving_position=...
                        [mh.trial.targets.(targ.name).moving_position; tempPos];
                    mh.trial.targets.(targ.name).timestamp=...
                        [mh.trial.targets.(targ.name).timestamp getsecs];
                    pixPos=deg2pix(tempPos,targ.degreestype,mh.screenparams);
                end
            end

            if any(matches(varargin(:),'center',IgnoreCase=true))
                out=pixPos;
            else
                if matches(targ.shape,'square',IgnoreCase=true) ||...
                        matches(targ.shape,'circle',IgnoreCase=true)
                    out=targ.squarepos(pixPos);
                end
            end
        end

        function out=squarepos(targ,tempPos)
            halfWidth=ceil(targ.size(3)-targ.size(1)/2);
            halfHeight=ceil(targ.size(4)-targ.size(2)/2);


            out=[tempPos(1)-halfWidth,...
                tempPos(2)-halfHeight,...
                tempPos(1)+halfWidth,...
                tempPos(2)+halfHeight];
        end

        function out=getcolor(t,mh,varargin)
            out=t.color(varargin{:});
        end

        function out=gettexture(t,mh,varargin)
            out=strcat('gr.target.',t.name,'.texture');
        end

        function out=targpos(t, idx)
            if nargin ==1
                out=t.position;
            else
                out=t.position(idx,:);
            end
        end

        function out=randpos(t,varargin) % i don't think i use this function
            if t.speed==0
                if nargin ==1
                    idx=randi(size(t.position,1));
                    out=t.position(idx,:);
                elseif strcmp(varargin{1},'square')
                    halfWidth=t.size(3)-t.size(1);
                    halfHeight=t.size(4)-t.size(2);
                    idx=randi(size(t.position,1));
                    out=[t.position(idx,1)-halfWidth,...
                        t.position(idx,2)-halfHeight,...
                        t.position(idx,1)+halfWidth,...
                        t.position(idx,2)+halfHeight];
                end
            else
                if nargin==1
                    idx=randi(size(t.position,1));
                    out=t.position(idx,:);
                elseif strcmp(varargin{1},'square')
                    halfWidth=t.size(3)-t.size(1);
                    halfHeight=t.size(4)-t.size(2);
                    idx=randi(size(t.position,1));
                    out=[t.position(idx,1)-halfWidth,...
                        t.position(idx,2)-halfHeight,...
                        t.position(idx,1)+halfWidth,...
                        t.position(idx,2)+halfHeight];
                end
            end
        end

        function out=randir(t, varargin)
            out=t.direction(randi(length(t.direction)));
        end
    end
end