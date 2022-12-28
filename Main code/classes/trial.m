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

        UserDefined =[]
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

        function obj = insert(obj,field,varargin)
            for i = 1:nargin-2
                if isempty(inputname(i+2))
                    name=[class(varargin{i}),num2str(varargin{i})];
                else
                    name=inputname(i+2);
                end
                if length(obj)==1
                    obj.(field).(name)=varargin{i};
                else
                    obj(end).(field).(name)=varargin{i};
                end
            end
        end


    end
end