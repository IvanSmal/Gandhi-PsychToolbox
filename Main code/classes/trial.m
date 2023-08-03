classdef trial < handle
    properties
        ttype

        tstarttime
        tstoptime = 0;
        trialnum = 0;

        state
        data=data
        targets
        success
        intervals

        UserDefined =[]

        System_Properties
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
            for i = 1:length(varargin)
                try
                    if length(obj)==1
                        obj.(field).(varargin{i}.name)=varargin{i};
                    else
                        obj(end).(varargin{i}.name)=varargin{i};
                    end
                catch
                    obj.(field).other_data{i}=varargin{:};
                end
            end
        end


    end
end