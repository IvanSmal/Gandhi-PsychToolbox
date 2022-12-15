classdef trial < handle
    properties
        tstarttime
        tstoptime = 0;
        trialnum = 0;

        state
        data=data
        targets
        success
        intervals
        
        reward = struct('reward',[],'tstart',[],'int',[]);

        PongState
    end
    
    methods
        function setstate(obj, name, time, count)
            obj.state.(name).time=time;
            if nargin == 4
                obj.state.(name).count=count;
            else
                obj.state.(name).count=length(obj.state);
            end
        end

        function setd(d,prop,varargin)
            for i=3:nargin
                d.(prop).(inputname(i))=varargin{i-2};
            end
        end
    end
end