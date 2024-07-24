classdef experiment
    
    properties
        subject_name
        DataDir
        parameter_file
        TrellisDir;
        LastParameters;
        trial=struct(trial); % individual trial info e.g. which targets were actually used. this is the one that will actually iterate
    end

    methods 
       
    end
end