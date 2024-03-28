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
                mh.trial.targets.(targ.name).moving_position=temppos;
                pixpos=deg2pix(temppos,targ.degreestype,mh.screenparams);
                
            else
                if ~any(matches(varargin(:),'continue',IgnoreCase=true))
                    curstate=mh.activestatename;
                    tim=getsecs-mh.trial.state.(curstate).time;
                    mh.targettime=mh.trial.state.(curstate).time;
                elseif any(matches(varargin(:),'continue',IgnoreCase=true))
                    try
                        curstate = varargin{end};
                        tim=getsecs-mh.trial.state.(curstate).time; 
                    catch
                        tim=getsecs-mh.targettime;
                        center=varargin(1);
                    end
                end
                
                if isempty(targ.custompath_x)
                    targpos=deg2pix(targ.position,targ.degreestype,mh.screenparams);

                    xyadd=deg2pix([targ.speed*cosd(targ.direction), targ.speed*sind(targ.direction)],'size',mh.screenparams);

                    tempx=targpos(1)+xyadd(3)*tim;
                    tempy=targpos(2)-xyadd(4)*tim;

                    pixpos=[tempx tempy];
                    temppos=pix2deg(pixpos,targ.degreestype,mh.screenparams);
                    mh.trial.targets.(targ.name).moving_position=...
                        [mh.trial.targets.(targ.name).moving_position; temppos];
                    mh.trial.targets.(targ.name).timestamp=...
                        [mh.trial.targets.(targ.name).timestamp getsecs];

                else
                    xf=@(mh,t,x) eval(targ.custompath_x);
                    yf=@(mh,t,y) eval(targ.custompath_y);
                    
                    tempx=xf(mh,tim*targ.speed,targ.position(1));
                    tempy=yf(mh,tim*targ.speed,targ.position(2));

                    temppos=[tempx tempy];
                    mh.trial.targets.(targ.name).moving_position=...
                        [mh.trial.targets.(targ.name).moving_position; temppos];
                    mh.trial.targets.(targ.name).timestamp=...
                        [mh.trial.targets.(targ.name).timestamp getsecs];
                    pixpos=deg2pix(temppos,targ.degreestype,mh.screenparams);
                end
            end

            if any(matches(varargin(:),'center',IgnoreCase=true))
                out=pixpos;
            else
                if matches(targ.shape,'square',IgnoreCase=true) ||...
                        matches(targ.shape,'circle',IgnoreCase=true)
                    out=targ.squarepos(pixpos);
                end
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