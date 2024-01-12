classdef interval
    properties
        name = 'example';
        duration = 200;
        prob = 1;
        sound = 0;
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

        function out=getint(in, yesname)
            if nargin==1
                if in.prob >= rand
                    out=in.duration(randi(length(in.duration)));
                else
                    out=0;
                end
            elseif yesname
                out.name=in.name;
                if in.prob >= rand
                    %out.duration = in.duration;
                    idx=randi([1,size(in.duration,2)]);
                    out.duration =in.duration(idx);
                else
                    out.duration=0;
                end
            end
        end
    end
end