classdef experiment < handle
    
    properties
        subject_name
        dir

        System_Properties internal
                
        intervals
        targets % database of targets to use in tasks
        windows % database of windows to use in tasks

        tasks=struct % shared properties for individual trial types (tasks)

        trial=trial % individual trial info e.g. which targets were actually used. this is the one that will actually iterate
    end

    methods 
        function addtarg(e,name,varargin)
            outcells={'name', name, varargin{:}};
            e.targets.(name)=target(outcells{:});            
        end

        function out=gettarg(e,name)
            out=e.targets.(name).randpos;         
        end

        function addint(e,name,dur, prob)
            if nargin ==3
                e.intervals.(name)=interval(name, dur);
            else
                e.intervals.(name)=interval(name, dur, prob);  
            end
        end

        function out=getint(e,name)
            out=e.intervals.(name).getint;         
        end

        function set(e,a,b)                                                 %general set function
            for i=length(e)
                e(i).(a)=b;
            end
        end

        function adddata(e,d)                                               %dump data in
            e.trial(e.trialnum).data=d;
        end

        function targinfo(e)
            flds=fields(e.targets);
            for i=1:length(flds)
                disp(e.targets.(flds{i}).name)
                disp(e.targets.(flds{i}).position)
            end
        end
    end
end