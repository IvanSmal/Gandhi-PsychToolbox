classdef target% < handle
    properties
        name
        size = [0 0 50 50]
        position = [0 0; 10 10; 20 20]
        twindow = 100;
        color = [1 0 0]
        shape = 'square'
        speed = 0
        direction 
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

        function rempos(t,pos)
            if length(pos)==1
                t.position(pos,:)=[];
            else
                [~,idx]=ismember(pos,t.position,'rows');
                if idx==0
                    error('target position does not exist')
                else
                    t.position(idx,:)=[];
                end
            end
        end

        function out=squarepos(t, idx)
            hwidth=t.size(3)-t.size(1);
            hheight=t.size(4)-t.size(2);
            if nargin ==1 
                out=[t.position(1)-hwidth,...
                    t.position(2)-hheight,...
                    t.position(1)+hwidth,...
                    t.position(2)+hheight];
            else
                out=[t.position(idx,1)-hwidth,...
                    t.position(idx,2)-hheight,...
                    t.position(idx,1)+hwidth,...
                    t.position(idx,2)+hheight];
            end
        end

        function out=targpos(t, idx)
            if nargin ==1 
                out=t.position;
            else
                out=t.position(idx,:);
            end
        end

        function out=randpos(t)
            idx=randi(size(t.position,1));
            out=t.position(idx,:);
        end
    end
end