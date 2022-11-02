function savestate(params)
%% save parameters and trials
    bckpname=fullfile([params.subject_name,datestr(now, '_yymmdd')],...
        datestr(now, 'HHMMSS'));
    mkdir(bckpname)

    taskpath=fullfile(fileparts(which('Main_function')), 'Tasks');
    copyfile(taskpath, fullfile(bckpname,'Tasks'))
    
    fileID = fopen(fullfile(bckpname, 'description.txt'),'W');
    fprintf(fileID,'%s','starting trial: ',num2str(params.trialnum));
    fclose(fileID);
%% back up data up to this point
    if exist('e','var')
        save(fullfile(bckpname(1:end-7),'e'),'e')
    end
end