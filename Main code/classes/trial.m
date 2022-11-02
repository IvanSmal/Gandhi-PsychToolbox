classdef trial < handle
    properties
        state
        data=data
        targets
        success
        intervals
    end
    
    methods
        function setstate(tr, name, time, count)
            tr.state.(name).time=time;
            if nargin == 4
                tr.state.(name).count=count;
            else
                tr.state.(name).count=length(tr.state);
            end
        end

        function setd(d,prop,varargin)
            for i=3:nargin
                d.(prop).(inputname(i))=varargin{i-2};
            end
        end
    end
end