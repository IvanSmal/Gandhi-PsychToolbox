classdef interval
    properties
        name = 'example';
        duration = 200;
        prob = 1;
    end
    methods
        function int = interval(name,dur,prob)
            if nargin==2
                int.name=name;
                int.duration=dur;
            else
                int.prob=prob;
            end
        end

        function out=getint(in, prob)
            if nargin==1
                if in.prob >= rand
                    out=in.duration;
                else
                    out=0;
                end
            else
                if prob >= rand
                    out = in.duration;
                else
                    out=0;
                end
            end
        end
    end
end