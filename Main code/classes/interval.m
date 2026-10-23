classdef interval
    properties
        name = 'example';
        duration = 200;
        prob = 1;
        sound = 0;
    end
    methods
        function obj = interval(name,durations,prob)
            if nargin==2
                obj.name=name;
                obj.duration=durations;
            else
                obj.prob=prob;
            end
        end

        function out=getint(obj, asStruct)
            if nargin==1
                if obj.prob >= rand
                    out=obj.duration(randi(length(obj.duration)));
                else
                    out=0;
                end
            elseif asStruct
                out.name=obj.name;
                if obj.prob >= rand
                    %out.duration = obj.duration;
                    durIdx=randi([1,size(obj.duration,2)]);
                    out.duration =obj.duration(durIdx);
                else
                    out.duration=0;
                end
            end
        end
    end
end
