function savestate(e)
%% save parameters and trials
    bckpname=fullfile(e.dir,...
        [e.subject_name,datestr(now, '_yymmdd')],...
        datestr(now, 'HHMMSS'));
    mkdir(bckpname)
    addpath(bckpname); 

    taskpath=fullfile(fileparts(which('Main_function')), 'Tasks');
    copyfile(taskpath, fullfile(bckpname,'Tasks'))
    
    fileID = fopen(fullfile(bckpname, 'description.txt'),'W');
    fprintf(fileID,'%s','starting trial: ',num2str(e.trialnum));
    fclose(fileID);
%% back up data up to this point
    save(fullfile(bckpname(1:end-7),'e'),'e')
end