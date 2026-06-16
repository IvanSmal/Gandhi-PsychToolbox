classdef MHost2_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        FileMenu                        matlab.ui.container.Menu
        ImportCustomFunctionsMenu       matlab.ui.container.Menu
        EnterDebugMenu                  matlab.ui.container.Menu
        ExitMenu                        matlab.ui.container.Menu
        UtilsMenu                       matlab.ui.container.Menu
        ScreenInfoMenu                  matlab.ui.container.Menu
        ResetGraphicsMenu               matlab.ui.container.Menu
        SpikeMonitorMenu                matlab.ui.container.Menu
        LiveAnalysisMenu                matlab.ui.container.Menu
        SoundGeneratorMenu              matlab.ui.container.Menu
        Button                          matlab.ui.control.Button
        ResetButton                     matlab.ui.control.Button
        TotalrewardsEditField           matlab.ui.control.NumericEditField
        TotalrewardsEditFieldLabel      matlab.ui.control.Label
        ImportPrametersButton           matlab.ui.control.Button
        GraphicsLamp                    matlab.ui.control.Lamp
        GraphicsLampLabel               matlab.ui.control.Label
        XippmexLamp                     matlab.ui.control.Lamp
        XippmexLampLabel                matlab.ui.control.Label
        StopRewardButton                matlab.ui.control.StateButton
        RewardButton                    matlab.ui.control.StateButton
        RewardDuration                  matlab.ui.control.NumericEditField
        FinalizeButton                  matlab.ui.control.Button
        STOPButton                      matlab.ui.control.StateButton
        STARTButton                     matlab.ui.control.Button
        InformationTextArea             matlab.ui.control.TextArea
        InformationTextAreaLabel        matlab.ui.control.Label
        RECORDNEURALDATACheckBox        matlab.ui.control.CheckBox
        TrellisDataDirButton            matlab.ui.control.Button
        TrellisDir                      matlab.ui.control.EditField
        ParameterFileButton             matlab.ui.control.Button
        ParameterFile                   matlab.ui.control.EditField
        LocalDataDirButton              matlab.ui.control.Button
        Dir                             matlab.ui.control.EditField
        SubjectNameEditField            matlab.ui.control.EditField
        SubjectNameEditFieldLabel       matlab.ui.control.Label
        TabGroup                        matlab.ui.container.TabGroup
        eyeTab                          matlab.ui.container.Tab
        EyeCalibrationPanel             matlab.ui.container.Panel
        AutoCalibTrials                 matlab.ui.control.NumericEditField
        yoffset                         matlab.ui.control.NumericEditField
        yoffsetEditFieldLabel           matlab.ui.control.Label
        ygain                           matlab.ui.control.NumericEditField
        ygainEditFieldLabel             matlab.ui.control.Label
        xoffset                         matlab.ui.control.NumericEditField
        xoffsetEditFieldLabel           matlab.ui.control.Label
        xgain                           matlab.ui.control.NumericEditField
        xgainEditFieldLabel             matlab.ui.control.Label
        UseAutoCalibrationValuesButton  matlab.ui.control.StateButton
        ResetAutoCalibrationButton      matlab.ui.control.Button
        SetCalibrationButton            matlab.ui.control.StateButton
        UniqueTargetsEditField          matlab.ui.control.NumericEditField
        yoffsetauto                     matlab.ui.control.NumericEditField
        ygainauto                       matlab.ui.control.NumericEditField
        xoffsetauto                     matlab.ui.control.NumericEditField
        xgainauto                       matlab.ui.control.NumericEditField
        AutoCalibrationLabel            matlab.ui.control.Label
        trialTab                        matlab.ui.container.Tab
        TrialnameEditField              matlab.ui.control.EditField
        TrialTargets                    matlab.ui.control.Table
        TrialIntervals                  matlab.ui.control.Table
        eyelinkTab                      matlab.ui.container.Tab
        SeteyelinkparametersButton      matlab.ui.control.Button
        Rawyoffset                      matlab.ui.control.NumericEditField
        RawyoffsetEditFieldLabel        matlab.ui.control.Label
        Rawxoffset                      matlab.ui.control.NumericEditField
        RawxoffsetEditFieldLabel        matlab.ui.control.Label
        monitorTab                      matlab.ui.container.Tab
        FontsizeEditField               matlab.ui.control.NumericEditField
        FontsizeEditFieldLabel          matlab.ui.control.Label
        XYguidelinesEditField           matlab.ui.control.EditField
        XYguidelinesEditFieldLabel      matlab.ui.control.Label
        SetGuidesButton                 matlab.ui.control.Button
        CircleguidesdegreesEditField    matlab.ui.control.NumericEditField
        CircleguidesdegreesEditFieldLabel  matlab.ui.control.Label
        ResetZoomButton                 matlab.ui.control.Button
        AdjustthiswhentrialsarestoppedLabel  matlab.ui.control.Label
        ZoomOutButton                   matlab.ui.control.Button
        ZoomInButton                    matlab.ui.control.Button
        LeftButton                      matlab.ui.control.Button
        DownButton                      matlab.ui.control.Button
        RightButton                     matlab.ui.control.Button
        UpButton                        matlab.ui.control.Button
        miscTab                         matlab.ui.container.Tab
        resetsuccessButton              matlab.ui.control.Button
        RepeatfailedtrialsEditField     matlab.ui.control.NumericEditField
        RepeatfailedtrialsEditFieldLabel  matlab.ui.control.Label
        TrialswithoutneuraldataLabel    matlab.ui.control.Label
        Trials_without_recording_counter  matlab.ui.control.NumericEditField
    end


    properties (Access = public)
        LiveParameters % acess to the parameters change
        spikemonitor
        ini = IniConfig();
        running=0; % Description
        mhpass
        checkForDataDirectory
        paramsloaded = 0;
        trellis_filebase='';
        chidx;
        filepaths=IniConfig();
        filepaths_path=[pwd '/inis/FilePaths.ini'];
        mhbackup;
        errored =0;

        %ITI memory
        last_trial_timestamp = 0
        last_trial_ITI = 0
        ITI_first=1
        post_trial_timer =0

        % repeating failed trials
        trials_failed = 0
        trials_failed_count = 0
        first_setstate = ''

        %counting successes
        success_counter=0;
    end

    properties (Access = private)
        CheckBoxCounter = 0; % counting how many trials were ran without recording neural data
        homepath; % Description
        post_trial_procedure_complete = 1; % Check that post trial procedure actually happened
    end

    methods (Access = public)

        function insToTxtbox(app,str)
            tstamp=string(datetime,'HH:mm:ss');
            combstr=append(tstamp, '> ', str);
            txtstr=sprintf('%s\n\n%s',combstr, string(get(app.InformationTextArea,'Value')));
            set(app.InformationTextArea,'Value',txtstr);
        end

        function savestate(app,e,stopped)
            %% save parameters and trials
            [~, ~, ~, H, M, S] = datevec(datetime('now'));
            hms=join(string([H, M, round(S)]));
            hms = regexprep(hms, ' +', '');

            mh=app.mhpass;

            datafilename=join([string(yyyymmdd(datetime)), e.subject_name,'temp']);app.ITI_first=0;
            datafilename = regexprep(datafilename, ' +', '_');

            app.checkForDataDirectory=fullfile(e.DataDir,datafilename);
            
            % generate temp trial name
            trnumber=num2str([zeros(1,5) mh.trial.trialnum]);
            trnumber = trnumber(find(~isspace(trnumber)));
            trname=['tr_' trnumber(end-5:end)];
            tempfname=fullfile(app.checkForDataDirectory,'temptrials',[trname '.mat']);

            if stopped
                bckpname=fullfile(app.checkForDataDirectory,hms);

                mkdir(bckpname);
                addpath(bckpname);

                taskpath=fullfile('.Tasks_Internal');
                copyfile(taskpath, fullfile(bckpname,'Tasks'))

                fileID = fopen(fullfile(bckpname, 'description.txt'),'W');
                fprintf(fileID,'\n%s\n%s\n%s','------------------','full info box text:','------------------');
                boxtext=app.InformationTextArea.Value;
                fprintf(fileID,'\n%s',string(boxtext));
                fclose(fileID);
                
                % check if graphics dumped the last file
                if isfile(tempfname)
                    temptr=load(tempfname);
                else
                    app.insToTxtbox('No temporary data file for this trial number found. Attempting to fix trial numbers')
                    % get files in dir
                    files=dir(fullfile(app.checkForDataDirectory,'temptrials'));
                    % load last file
                    lastfile=load([files(end).folder,'/',files(end).name]);
                    %get last trial number
                    truetrnum=lastfile.(files(end).name(1:end-4)).trialnum;
                    %add one
                    truetrnum =truetrnum+1;
                    % insert new trial number to the persistent trnumber
                    % and the current trial
                    app.mhpass.trial.trialnum=truetrnum;
                    app.mhpass.trialnumpersistent = truetrnum;

                    %generate new trial file
                    trnumber=num2str([zeros(1,5) app.mhpass.trial.trialnum]);
                    trnumber = trnumber(find(~isspace(trnumber)));
                    trname=['tr_' trnumber(end-5:end)];
                    eval([trname '=app.mhpass.trial;']);
                    tempfname=fullfile(app.checkForDataDirectory,'temptrials',[trname '.mat']);
                    
                    app.insToTxtbox('fixed trial numbers.')
                end
                try
                fliptimes_exist = isempty(temptr.(trname).data.graphics_fliptimes.fliptimes);
                if ~fliptimes_exist
                    try %asking one more time for the graphics to dump the data please
                        mh.evalgraphics(join(['dumpdata("', tempfname, '");']))
                        disp('(161) sent dumpdata command')
                    catch
                        keyboard
                    end
                end
                catch
                end
                clear temptr
            else
                %% back up data up to this point
                eval([trname '=app.mhpass.trial;']);

                response=0; %restet graphics response    
                if exist(fullfile(app.checkForDataDirectory,'temptrials'),'dir')
                    if exist(tempfname,'file')
                        app.insToTxtbox(['trial file: ' tempfname ' already exists. Will attempt to fix trial numbers.'])
                        % get files in dir
                        files=dir(fullfile(app.checkForDataDirectory,'temptrials'));
                        % load last file
                        lastfile=load([files(end).folder,'/',files(end).name]);
                        %get last trial number
                        truetrnum=lastfile.(files(end).name(1:end-4)).trialnum;
                        %add one
                        truetrnum =truetrnum+1;
                        % insert new trial number to the persistent trnumber
                        % and the current trial
                        app.mhpass.trial.trialnum=truetrnum;
                        app.mhpass.trialnumpersistent = truetrnum;
    
                        %generate new trial file
                        trnumber=num2str([zeros(1,5) app.mhpass.trial.trialnum]);
                        trnumber = trnumber(find(~isspace(trnumber)));
                        trname=['tr_' trnumber(end-5:end)];
                        eval([trname '=app.mhpass.trial;']);
                        tempfname=fullfile(app.checkForDataDirectory,'temptrials',[trname '.mat']);
                        
                        app.insToTxtbox('fixed trial numbers.')
                    end
                    save(tempfname,trname);
                    mh.evalgraphics(join(['dumpdata("', tempfname, '");']))
                    response = mh.WaitForGraphics;
                else
                    mkdir(fullfile(app.checkForDataDirectory,'temptrials'));                    
                    save(tempfname,trname);
                    mh.evalgraphics(join(['dumpdata("', tempfname, '");']))
                    response = mh.WaitForGraphics;
                end
    
                if ~response
                    app.insToTxtbox('Graphics did not reply after being asked to save data to trial file.')
                end
            end

            e=struct(e);
            clasdefpath_temp=what('classes');
            clasdefpath=fullfile(clasdefpath_temp.path);
            copyfile(clasdefpath, fullfile(app.checkForDataDirectory,'class_definitions'));

            save(fullfile(app.checkForDataDirectory,'e'),'e');

            app.mhpass=mh;
        end
    end

    methods (Access = private)
        function [mh,e] = Run_Experiment(app,mh)
            try
                if app.errored
                    temptrialnumpersistent=mh.trialnumpersistent;
                    % mh=copy(app.mhbackup);
                    mh=app.mhpass;
                    app.insToTxtbox('mh pointed to a backup mhpass due to an app.errored tag on line 272.')
                    mh.trialnumpersistent=temptrialnumpersistent;
                    app.errored=0;
                end
                %% set all the parameters up
                app.trellis_filebase = [app.TrellisDir.Value,'/',app.SubjectNameEditField.Value];
                if isempty(app.checkForDataDirectory) || ~isfile(fullfile(fullfile(app.checkForDataDirectory,'e.mat')))
                    e = make_e(app);
                else
                    [~, ~, ~, H, M, S] = datevec(datetime('now'));
                    hms=join(string([H, M, round(S)]));
                    hms = regexprep(hms, ' +', '');

                    datafilename = join([string(yyyymmdd(datetime)), app.SubjectNameEditField.Value,'temp']);
                    datafilename = regexprep(datafilename, ' +', '_');

                    checkdirstr=fullfile(app.Dir.Value,datafilename);

                    if strcmp(app.checkForDataDirectory,checkdirstr)
                        load(fullfile(checkdirstr,'e.mat'),'e');
                     else
                        WARNING=questdlg('Detected a continuation of a session, but could not find the data file in the temp folder. YOUR DATA PRIOR TO THIS TRIAL MAY BE PERMANENTLY DELETED IF YOU CONTINUE THIS SESSION!', ...
                            'WARNING!', ...
                            'STOP','continue','STOP');
                        switch WARNING
                            case 'continue'
                                e=make_e(app);
                            case 'STOP'
                                set(app.STOPButton,'enable','off')
                                set(app.STARTButton,'enable','on')

                                set(app.STOPButton,'Value',0)
                                app.FinalizeButton.Enable = 'on';
                                clearvars -except app mh e
                                app.running=0;
                                return
                        end
                    end
                end
                %% check for name change
                if ~strcmp(e.subject_name,app.SubjectNameEditField.Value)
                    app.insToTxtbox(['Changed subject name to: ' app.SubjectNameEditField.Value]);
                    e.subject_name = app.SubjectNameEditField.Value;
                    e.DataDir = app.Dir.Value;
                    e.TrellisDir=app.TrellisDir.Value;
                    e.parameter_file=app.ParameterFile.Value;
                end

                %% update the eccenticity gain and screen parameters
                app.ini.ReadFile('inis/ScreenParams.ini');
                mh.eccentricity_gain = app.ini.GetValues('target window parameters','eccentricity_gain');
                mh.trailing_window_time = app.ini.GetValues('target window parameters','trailing_window_time');
                mh.screenparams.xPixelSize=app.ini.GetValues('for deg2pix','xPixelSize');
                mh.screenparams.yPixelSize=app.ini.GetValues('for deg2pix','yPixelSize');
                mh.screenparams.true_center=app.ini.GetValues('for deg2pix','true center');
                mh.screenparams.subject_distance=app.ini.GetValues('for deg2pix','subject distance');

                if app.paramsloaded==0

                    e.parameterfile=app.ParameterFile.Value;
                    app.makeparams

                end

                %% disalow data archiving
                set(app.FinalizeButton,'Enable','off')

                %% allow trial stoppage
                set(app.STOPButton,'Enable','on')
                mh.failcounter=0;
                while ~app.STOPButton.Value && app.post_trial_procedure_complete
                    app.post_trial_procedure_complete = 0;
                    try
                        xippmex('trial', 'stopped'); %force xippmex to end previous trial
                    catch

                    end

                    mh.rewcheck(app,1);
                    % get the logic for which trial to do next
                    mh.ttypeslogic = app.LiveParameters.FilesTable.Data;

                    totalrelativeprob=sum([mh.ttypeslogic{:,2}]);
                    if any(isnan(totalrelativeprob))
                        app.insToTxtbox('One of the trials set to NaN');
                        set(app.STOPButton,'Value',1);
                        break
                    end
                    if totalrelativeprob<1
                        app.insToTxtbox('All trials set to 0');
                        set(app.STOPButton,'Value',1);
                        break
                    end
                    tlist=cell(totalrelativeprob);
                    count=0;
                    for i=1:size(mh.ttypeslogic,1)
                        for ii=1:cell2mat(mh.ttypeslogic(i,2))
                            count=count+1;
                            tlist{count}=mh.ttypeslogic(i,1);
                        end
                    end
                    randTrial=randi(size(tlist,1));
                    mh.trial=trial;%clear any old BS from trial
                    trialtypestring=char(tlist{randTrial});
                    mh.trial.ttype=trialtypestring(1:end-2);
                    mh.trial_function=str2func(mh.trial.ttype);

                    %%
                    % check if autocalibrate buffer changed
                    if ~isempty(mh.autocalibrationmatrix)
                        app.UniqueTargetsEditField.Value=size(mh.autocalibrationmatrix,1);
                    else
                        app.UniqueTargetsEditField.Value=0;
                    end
                    % see if any targets changed
                    ttable=app.LiveParameters.TargetsTable.Data;
                    for i=1:size(ttable,1)
                        eval(['temp=[' ttable{i,2} '];']); % I have no idea why I do it this way but if i change it it breaks
                        mh.targets.(ttable{i,1}).position=temp;
                        if any(matches(["cart","cartesian","pol","polar"],ttable{i,3},Ignorecase=1))
                            mh.targets.(ttable{i,1}).degreestype=ttable{i,3};
                        else
                            warndlg('One of the targets has an invalid degrees type')
                        end
                        mh.targets.(ttable{i,1}).window=str2num(ttable{i,4});

                        tempsize=str2num(ttable{i,5});
                        truesize=deg2pix(tempsize,'size');

                        mh.targets.(ttable{i,1}).size=truesize;
                        mh.targets.(ttable{i,1}).speed=str2num(ttable{i,6});
                        mh.targets.(ttable{i,1}).direction=str2num(ttable{i,7});
                        clear temp
                        mh.targtable=ttable;
                    end

                    % see if any intervals changed
                    ttable=app.LiveParameters.IntervalsTable.Data;
                    for i=1:size(ttable,1)
                        eval(['temp=[' ttable{i,2} '];']);
                        mh.intervals.(ttable{i,1}).duration=temp;
                        mh.intervals.(ttable{i,1}).prob=str2num(ttable{i,3});
                        mh.intervals.(ttable{i,1}).sound=str2num(ttable{i,4});
                        clear temp
                        mh.intervaltable=ttable;
                    end
                    %%

                    %see if calibration changed
                    mh.eye=eyeinfo;

                    mh.trialnumpersistent = mh.trialnumpersistent+1;
                    mh.trial.trialnum=mh.trialnumpersistent;

                    % display success trial number
                    app.insToTxtbox([app.TrialnameEditField.Value, '. Trial number: ', num2str(mh.trial.trialnum),'    success: ', num2str(app.success_counter)]);

                    %check trellis
                    setupDAQ(app);


                    if app.RECORDNEURALDATACheckBox.Value
                        trellisrecording=1;
                        app.STOPButton.Value = 0;
                        try
                            trinfo=xippmex('trial', 'recording',app.trellis_filebase,[],[1]);%
                        catch
                            app.insToTxtbox('could not start trial for some reason. Trying to restart.')
                            try
                                xippmex('trial', 'stopped');
                                pause(0.01)
                                trinfo=xippmex('trial', 'recording',app.trellis_filebase,[],[1]);
                                app.insToTxtbox('restart successful')
                            catch
                                app.insToTxtbox('could not start trellis trial. stopping.')
                                app.STOPButton.Value = 1;
                                break
                            end
                        end
                        if trinfo.incr_num >50000
                            app.insToTxtbox('trellis numbers are looking weird, please check.')
                            errordlg('trellis numbers are looking weird, please check.');
                            app.STOPButton.Value=1;
                            break;
                        end
                        mh.trial.trellis_trial_number=trinfo.incr_num;
                    elseif app.CheckBoxCounter == app.Trials_without_recording_counter.Value
                        warndlg("Ran 25 trials without recording neural data!!")
                        app.CheckBoxCounter = 0;
                        app.STOPButton.Value = 1;
                    else
                        trellisrecording=0;
                        app.CheckBoxCounter=app.CheckBoxCounter+1;
                    end
                    mh.evalgraphics('gr.trialstarted=1;');
                    %% ******** trial in this loop ********
                    a=[];
                    % [~,~,events]=xippmex('digin'); %clear digital buffer
                    gotinfo=0;
                    xippmex('digout', 1, 1)
                    [eyeandphotodiode, xippmextstart]=xippmex('cont',app.chidx([1,2,4]),1000,'1ksps');

                    % ITI check
                    gotiti=0;
                    while (app.last_trial_timestamp+app.last_trial_ITI)>getsecs %% ITI
                        gotiti=1;
                        pause(0.001)
                        mh.rewcheck(app);
                        try
                            com=readline(mh.rewardport);
                            eval(com);
                        end
                    end
                                        
                    if ~gotiti && ~app.ITI_first
                        app.insToTxtbox('iti was probably incorrect')
                    end
                    if ~app.ITI_first
                        fprintf('(477) ran start trial procedure and paused for ITI at %f \n' , toc(app.post_trial_timer))
                    end                    
                    
                    while mh.runtrial==1 %&& ~app.STOPButton.Value
                        tic
                        mh.graphicssent=1; % check if needed

                        if app.trials_failed
                            mh=copy(app.mhbackup); %revert to last parameters/targets
                            mh.trialnumpersistent = mh.trialnumpersistent+1;
                            mh.trial.trialnum=mh.trialnumpersistent; %fix trial numbers
                            toRemove={'tstarttime','tstoptime','state','data','System_Properties'}; % set structures to remove
                            for remove=toRemove
                                mh.trial.(remove{1})=[]; %actually clear
                            end
                            if app.RECORDNEURALDATACheckBox.Value
                                mh.trial.trellis_trial_number=trinfo.incr_num; %fix correct trellis number
                            end
                            mh.starttrial
                            mh.setstate(app.first_setstate) %perform trial start procedure
                            app.insToTxtbox(['Repeating failed trial ' num2str(app.trials_failed_count) ' time(s)'])
                            app.trials_failed = 0;
                        end

                        mh = mh.trial_function(mh);

                        mh.Screen('sendtogr')
                        mh.graphicssent=0; % check if needed
                        [eyeandphotodiode_temp, ts]=xippmex('cont',app.chidx([1,2,4]),300,'1ksps');
                        tsshift=floor((ts-xippmextstart)/30);
                        eyeandphotodiode(:,tsshift+1:300+tsshift)=eyeandphotodiode_temp;

                        if ~gotinfo
                            app.gettrialinfo(mh) %this gets all the targets and intervals from the trial to display on the GUI
                            gotinfo=1;
                        end

                        if app.STOPButton.Value == 1 %check for force stop trial
                            mh.stoptrial(0);
                        end

                        mh.rewcheck(app);
                        a=[a toc];
                        if length(a)>5 && a(end)>10
                            app.insToTxtbox(['Check time was slow: ' num2str(a(end))  'ms.'])
                        end
                        app.spikemonitor.mh = mh;
                    end
                    %% post trial
                    app.post_trial_timer=tic;
                    xippmex('digout', 1, 0)
                    fprintf('(483-485) shut off digital 1 %f \n' , toc(app.post_trial_timer))
                    % check if trial was failed
                    if mh.trial.success
                        app.trials_failed_count = 0;
                        app.trials_failed = 0;

                        app.success_counter = app.success_counter+1;
                    else

                        oldstates=fields(mh.trial.state);
                        app.first_setstate = oldstates{2}; %grab the first user-designated trial

                        app.trials_failed = 1;
                        app.trials_failed_count = app.trials_failed_count+1;
                        if app.trials_failed_count > app.RepeatfailedtrialsEditField.Value
                            app.trials_failed_count = 0;
                            app.trials_failed = 0;
                        end
                    end
                    %append eye and photodiode into the structure
                    mh.trial.tstoptime=getsecs;
                    eyeandphotodiode=eyeandphotodiode(:,999:end); %
                    eyeandphotodiode(1,:)=eyeandphotodiode(1,:)*mh.eye.xgain+mh.eye.xoffset;
                    eyeandphotodiode(2,:)=eyeandphotodiode(2,:)*mh.eye.ygain+mh.eye.yoffset;
                    xy_deg=pix2deg([eyeandphotodiode(1,:)',eyeandphotodiode(2,:)'],'cart', mh.screenparams);

                    fprintf('(485-494) combined eye data %f \n' , toc(app.post_trial_timer))
                    mh.rewcheck(app);

                    d=data;   %initialize empty data  
                    d.eyepos=xy_deg';
                    if length(d.eyepos(1,:))>40
                        if all(diff(d.eyepos(1,20:end-20))<2)
                            app.insToTxtbox('No eye movement detected in trial!')
                        end
                    end
                    d.neural_data='placeholder';
                    d.photodiode(1,:)=eyeandphotodiode(3,:);
                    ts_temp=1:length(d.eyepos);
                    d.timestamps=ts_temp+floor(mh.trial.tstarttime*1000);
                    clear eyeandphotodiode;
                    fprintf('(493-508) inserting data to structure finished at %f \n' , toc(app.post_trial_timer))                    

                    mh.evalgraphics('gr.trialstarted=0;gr.diode_color=[0;0;0]; disp("end trial diode off");')
                    fprintf('(508-511) turned diode off at %f \n' , toc(app.post_trial_timer))

                    app.getautocalibratefit                    

                    % app.insToTxtbox(['average check time: ' num2str(mean(a(10:end-10)))]);

                    if ~mh.trial.success
                        mh.failcounter=mh.failcounter+1;
                        mh.autocalibrationmatrix_buffer = [];
                    else
                        mh.autocalibrationmatrix = mh.autocalibrationmatrix_buffer;
                        mh.autocalibrationtrials=mh.autocalibrationtrials+1;
                        app.AutoCalibTrials.Value=mh.autocalibrationtrials;
                        mh.failcounter=0;
                    end
                    

                    mh.runtrial=1; % activate next trial

                    app.calibration_check(mh);
                    fprintf('(511-531) made a fit for autocalibration at %f \n' , toc(app.post_trial_timer))

                    mh.trial.data=struct(d);
                    
                    %save system properties
                    e.LastParameters=mh;

                    %save system properties but in an easier to digest form
                    tempmh= struct(mh);
                    mh.rewcheck(app);
                    PropertiesToSave={'trial_function', 'intervals', 'targets','movie','tex','diode_pos','diode_color','eye','targhistory','rew','ttypeslogic'};
                    for propnumber =1:length(PropertiesToSave)
                        mh.rewcheck(app);
                        mh.trial.System_Properties.(PropertiesToSave{propnumber})=...
                            tempmh.(PropertiesToSave{propnumber});
                    end
                    clear tempmh PropertiesToSave
                    % put in rewards into trial structure
                    mh.trial.reward=mh.rewardcount;
                    mh.rewardcount=0;
                    fprintf('(531-551) formatted parameters to fit into data structure %f \n' , toc(app.post_trial_timer))
                    app.mhpass=mh;
                    app.savestate(e,0);
                    fprintf('(551-553) ran app.savestate(e,0) %f \n' , toc(app.post_trial_timer))                    
                    
                    try
                        %check of the reward handler is talking
                        com=readline(mh.rewardport);
                        eval(com);
                    end
                    fprintf('(553-562) talked to reward handler at %f \n' , toc(app.post_trial_timer))

                    if trellisrecording ==1
                        try
                            xippmex('trial', 'stopped');
                        catch
                            app.insToTxtbox('Could not stop trellis trial recording. Are there issues with trellis? retrying');
                            try
                                xippmex('trial', 'stopped');
                            catch
                                app.insToTxtbox('Retry failed. Stopping trials.');
                                app.STOPButton.Value = 1;
                            end
                        end
                    end

                    if mh.failcounter>=app.LiveParameters.MaxConsecutiveFailuresEditField.Value
                        app.insToTxtbox('maximum trial failure reached.')
                        app.STOPButton.Value=1;
                    end
                    
                    app.mhbackup=copy(mh); %make a backup
                    mhbackuptrialnum = num2str(app.mhbackup.trial.trialnum);
                    app.insToTxtbox(['backup trial number: ' mhbackuptrialnum])
                    app.insToTxtbox(['backup persistent trial count: ' num2str(app.mhbackup.trialnumpersistent)])
                    app.mhpass=mh;
                    app.running=1;

                    while matlabUDP_gandhi('check', mh.graphicsport)
                        matlabUDP_gandhi('receive', mh.graphicsport);
                    end % flush the graphics

                    xippmex('close'); %this might prevent xippmex errors
                    
                    app.last_trial_ITI=mh.intervals.iti.duration;
                    app.last_trial_timestamp=mh.trial.tstoptime;
                    app.ITI_first=0;

                    app.post_trial_procedure_complete = 1;
                end
                %% ending procedure
                app.trials_failed = 0; %make it so changes can be applied on start
                app.trials_failed_count = 0; %^^

                set(app.FinalizeButton,'Enable','on')

                mh.rewcheck(app);
                app.mhpass=mh;
                app.savestate(e,1); %check this. it's a mess   \
                if ~app.post_trial_procedure_complete
                     app.insToTxtbox('post-trial was not done in previous trial');
                     app.post_trial_procedure_complete = 1;
                end
                
                app.insToTxtbox('did ending procedure');

                mh.rewcheck(app);

                set(app.STOPButton,'enable','off')
                set(app.STARTButton,'enable','on')

                set(app.STOPButton,'Value',0);
                app.FinalizeButton.Enable = 'on';

                app.running=0;

            catch err % error handling
                app.errored = 1;
                logError(app, err, 'Run_Experiment');

                app.insToTxtbox('Attempting to perform end of trial procedure')
                try
                    [mh,e] = app.EmergencyTrialEndingProcedure(mh,e);
                catch emergencyErr
                    logError(app, emergencyErr, 'EmergencyTrialEndingProcedure');
                    app.insToTxtbox('COULD NOT PERFORM END OF TRIAL PROCEDURE!')
                end

                set(app.STOPButton, 'enable', 'off')
                set(app.STARTButton, 'enable', 'on')
                app.mhbackup.trialnumpersistent = app.mhpass.trialnumpersistent;
                app.mhpass = copy(app.mhbackup);
                app.insToTxtbox('backup loaded due to an error in Run_Experiment.')
                app.idle_loop;
                app.insToTxtbox('Performed end of trial procedure. Check for errors in parameters and try again.')
            end
        end

        function getParams(app,fpath)
            try
                if contains(fpath(end-4:end),'.mat')
                    load(fpath)
                elseif contains(fpath(end-4:end),'.zip')
                    tempdir=fullfile(fileparts(fpath),'temp');
                    unzip(fpath,tempdir)
                    finde=dir([tempdir '/*/']);
                    eidx=cellfun(@(x) contains(x,'.mat'),{finde.name});
                    load(fullfile(finde(eidx).folder,finde(eidx).name))
                    sys_cmd = sprintf( 'rmdir -rf "%s"', tempdir );
                    system( sys_cmd );
                end

                app.ygain.Value = e.trial(end).System_Properties.eye.ygain;
                app.yoffset.Value = e.trial(end).System_Properties.eye.yoffset;
                app.xgain.Value = e.trial(end).System_Properties.eye.xgain;
                app.xoffset.Value = e.trial(end).System_Properties.eye.xoffset;

                app.SubjectNameEditField.Value = e.subject_name;
                app.Dir.Value=e.DataDir;

                app.LiveParameters.FilesTable.Data=e.trial(end).System_Properties.ttypeslogic;

                %load target info
                targnames=fieldnames(e.trial(end).System_Properties.targets);
                for i=1:numel(targnames)
                    pos{i,:}=[];
                    for ii=1:size(e.trial(end).System_Properties.targets.(targnames{i}).position,1)
                        pos{i,:}=[pos{i,:} num2str(e.trial(end).System_Properties.targets.(targnames{i}).position(ii,:)) ';'];
                    end
                    col{i,:}=num2str(e.trial(end).System_Properties.targets.(targnames{i}).color);
                    sz{i,:}=num2str(e.trial(end).System_Properties.targets.(targnames{i}).size);
                end
                targtable=[targnames,pos,col,sz];

                set(app.LiveParameters.TargetsTable,'Data',targtable);

                %load interval infoS
                intnames=fieldnames(e.trial(end).System_Properties.intervals);
                for i=1:numel(intnames)
                    tim{i,:}=[];
                    for ii=1:size(e.trial(end).System_Properties.intervals.(intnames{i}).duration,1)
                        tim{i,:}=[tim{i,:} num2str(e.trial(end).System_Properties.intervals.(intnames{i}).duration(ii,:)) ';'];
                    end
                    prop{i,:}=num2str(e.trial(end).System_Properties.intervals.(intnames{i}).prob);
                    sound{i,:}=num2str(e.trial(end).System_Properties.intervals.(intnames{i}).sound);
                end
                targtable=[intnames,tim,prop,sound];

                set(app.LiveParameters.IntervalsTable,'Data',targtable);

                %create internal structure
                mh= app.mhpass;
                [parpath, parname] = fileparts(e.parameterfile);
                addpath(parpath)
                eval([parname ';']);
                mh.trial=trial;
                mh.trialstarted = 0;
                mh.trialnumpersistent=0;
                mh.diode_on = 0;
                app.paramsloaded = 1;
                app.mhpass = mh;
            catch
                % msgstr=['tried to load "' fpath '" but could not load parameters from it. Is it empty? Corrupted?'];
                % app.insToTxtbox(msgstr)
            end
        end

        function calibration_check(app,mh)
            try     % this 'try' is here because for some unknown reason this fnction is run after app is closed.
                if app.SetCalibrationButton.Value
                    app.addnewoffsets

                    app.ini.ReadFile('inis/ScreenParams.ini');

                    app.ini.SetValues('reward','reward',...
                        app.RewardDuration.Value)

                    app.ini.WriteFile('inis/ScreenParams.ini');
                    % mh.autocalibrationmatrix=[];
                    mh.eye=eyeinfo;
                    mh.Screen('seteye')

                    app.SetCalibrationButton.Value=0;
                end
            catch
            end
        end

        function makeparams(app)
            mh=app.mhpass;
            mh.clearparamproperties;
            [~,paramfile]=fileparts(app.ParameterFile.Value);
            run(['.Parameters_Internal/' paramfile]);
            app.paramsloaded = 1;
            app.mhpass=mh;

            %% shove target info into gui table if no parameters were loaded
            targnames=fieldnames(mh.targets);
            for i=1:numel(targnames)
                pos_internal{i,:}=[];
                sz{i,:}=[];
                sp{i,:}=[];
                dir{i,:}=[];
                win{i,:}=[];

                for ii=1:size(mh.targets.(targnames{i}).position,1)
                    pos_internal{i,:}=[pos_internal{i,:} num2str(mh.targets.(targnames{i}).position(ii,:)) ';'];
                end

                for ii=1:size(mh.targets.(targnames{i}).size,1)
                    tempsize=mh.targets.(targnames{i}).size(ii,:);
                    degsize=pix2deg([tempsize(3:4)],'size');

                    sz{i,:}=[sz{i,:} num2str(degsize)];
                end

                for ii=1:size(mh.targets.(targnames{i}).speed,1)
                    sp{i,:}=[sp{i,:} num2str(mh.targets.(targnames{i}).speed(ii,:)) ';'];
                end

                for ii=1:size(mh.targets.(targnames{i}).direction,1)
                    dir{i,:}=[dir{i,:} num2str(mh.targets.(targnames{i}).direction(ii,:)) ';'];
                end

                for ii=1:size(mh.targets.(targnames{i}).window,1)
                    win{i,:}=[win{i,:} num2str(mh.targets.(targnames{i}).window(ii,:)) ';'];
                end

                degtype{i,:}=num2str(mh.targets.(targnames{i}).degreestype);
            end
            targtable=[targnames,pos_internal,degtype,win,sz,sp,dir];

            set(app.LiveParameters.TargetsTable,'Data',targtable);

            %% shove interval info into gui table if no parameters were loaded
            intnames=fieldnames(mh.intervals);
            for i=1:numel(intnames)
                tim{i,:}=[];
                prob{i,:}=[];
                sound{i,:}=[];
                for ii=1:size(mh.intervals.(intnames{i}).duration,1)
                    tim{i,:}=[tim{i,:} num2str(mh.intervals.(intnames{i}).duration(ii,:)) ';'];
                end
                prob{i,:}=num2str(mh.intervals.(intnames{i}).prob);
                sound{i,:}=num2str(mh.intervals.(intnames{i}).sound);
            end
            targtable_ints=[intnames,tim,prob,sound];

            set(app.LiveParameters.IntervalsTable,'Data',targtable_ints);

            app.mhbackup=copy(mh);

            app.paramsloaded=1;
        end

        function idle_loop(app)
            try
                %% show eye position/ idle loop
                onceinawhile=99;
                while ~app.running
                    onceinawhile=onceinawhile+1;
                    pause(0.001) %help gui
                    drawnow %help gui
                    mh=app.mhpass;
                    mh.rewcheck(app);
                    app.calibration_check(mh);
                    if onceinawhile == 100
                        setupDAQ(app);
                        app.CheckGraphics(10);
                        onceinawhile=0;
                        xippmex('close');
                    end
                    app.mhpass=mh;
                    try
                        com=readline(mh.rewardport);
                        eval(com);
                    end
                end
            catch err
                app.errored = 1;
                logError(app, err, 'idle_loop');

                app.mhbackup.trialnumpersistent = app.mhpass.trialnumpersistent;
                app.mhpass = copy(app.mhbackup);
                app.insToTxtbox('backup loaded due to error in idle_loop')
                app.idle_loop
            end
        end

        function [mh,e] = EmergencyTrialEndingProcedure(app,mh,e)


            set(app.STOPButton,'enable','off')
            set(app.STARTButton,'enable','on')

            if ~mh.trial.success
                mh.failcounter=mh.failcounter+1;
            else
                mh.failcounter=0;
            end
            while matlabUDP_gandhi('check', mh.graphicsport)
                matlabUDP_gandhi('receive', mh.graphicsport);
            end % flush the graphics
            mh.runtrial=1; % activate next trial

            app.calibration_check(mh);
            mh.rewcheck(app);

            mh.evalgraphics('gr.diode_color=[0;0;0]; disp("end trial diode off");')
            try
                xippmex('trial', 'stopped');
            catch
                % do nothing
            end

            mh.rewcheck(app);
            app.mhpass=mh;
            app.savestate(e,1); %check this. it's a mess

            mh.trial=trial; %erase trial again just to be sure
            app.mhpass=mh;
            % check if mh.trial resets every trial
            set(app.FinalizeButton,'Enable','on')

            mh.rewcheck(app);
            % [~,~,events]=xippmex('digin'); %clear digital buffer

            app.FinalizeButton.Enable = 'on';

            app.running=0;

            app.idle_loop
        end

        function ClearHiddenFolders(app,cleartasks, clearfunctions)
            if exist(".Parameters_Internal", 'dir')
                rmdir(".Parameters_Internal","s");
            end
            mkdir(".Parameters_Internal");
            addpath(".Parameters_Internal")
            if cleartasks
                if exist(".Tasks_Internal", 'dir')
                rmdir('.Tasks_Internal', 's');
                end
                mkdir(".Tasks_Internal")
                addpath(".Tasks_Internal")
            end
            if clearfunctions
             if exist(".Custom_Functions", 'dir')
                rmdir('.Custom_Functions', 's');
             end
            mkdir(".Custom_Functions");
            addpath(".Custom_Functions")
            end

        end

        function getautocalibratefit(app)
            mh=app.mhpass;
            if size(mh.autocalibrationmatrix,1)<3
                app.xoffsetauto.Value=0;
                app.yoffsetauto.Value=0;
                app.xgainauto.Value=0;
                app.ygainauto.Value=0;
            else
                forx=mh.autocalibrationmatrix(:,[1,2]);
                fory=mh.autocalibrationmatrix(:,[3,4]);
                if var(forx(:,1))<200 || var(fory(:,1))<200
                    %msgbox('Variance of target positions in one of the dimensions is too small');
                    app.UseAutoCalibrationValuesButton.Value = 0;
                else
                    tc=mh.screenparams.true_center;
                    %x regression
                    xgainoffset= polyfit(forx(:,2),forx(:,1),1);
                    app.xgainauto.Value = round(xgainoffset(1),3);
                    app.xoffsetauto.Value = pix2deg([round(xgainoffset(2),3)+tc(1)-app.Rawxoffset.Value nan],'cart');

                    %y regression
                    ygainoffset=polyfit(fory(:,2),fory(:,1),1);
                    app.ygainauto.Value = round(ygainoffset(1),3);
                    app.yoffsetauto.Value = pix2deg([nan round(ygainoffset(2),3)+tc(2)-app.Rawyoffset.Value],'cart');
                end
            end
        end

        function gettrialinfo(app,mh)
            % name
            app.TrialnameEditField.Value=mh.trial.ttype;
            %targets
            targs=fieldnames(mh.trial.targets);
            targnames=cell(length(targs) ,1);
            targpos=cell(length(targs) ,1);
            targspeed=cell(length(targs) ,1);
            targdir=cell(length(targs) ,1);
            for i=1:length(targs)
                targnames{i,1}=mh.trial.targets.(targs{i}).name;
                targpos{i,1}=num2str(mh.trial.targets.(targs{i}).position);
                targspeed{i,1}=num2str(mh.trial.targets.(targs{i}).speed);
                targdir{i,1}=num2str(mh.trial.targets.(targs{i}).direction);
            end
            set(app.TrialTargets,'Data',[targnames, targpos, targspeed, targdir])

            %intervals
            ints=fieldnames(mh.trial.intervals);
            intnames=cell(length(ints),1);
            intdur=cell(length(ints),1);
            for i=1:length(ints)
                intnames{i,1}=mh.trial.intervals.(ints{i}).name;
                intdur{i,1}=num2str(mh.trial.intervals.(ints{i}).duration);
            end
            set(app.TrialIntervals,'Data',[intnames, intdur])
        end

        function addnewoffsets(app)
            app.ini.ReadFile('inis/ScreenParams.ini');

            xoff=app.ini.GetValues('eye calibration','xoffset');

            yoff=app.ini.GetValues('eye calibration','yoffset');

            true_zero=app.ini.GetValues('for deg2pix','true center');

            truexoffset=xoff+deg2pix([app.xoffset.Value nan],'cart')-true_zero(1);
            trueyoffset=yoff+deg2pix([nan app.yoffset.Value],'cart')-true_zero(2);

            app.ini.SetValues('eye calibration',{'xoffset','xgain','yoffset','ygain'},...
                {truexoffset,...
                app.xgain.Value,...
                trueyoffset,...
                app.ygain.Value});

            app.Rawxoffset.Value=truexoffset;
            app.Rawyoffset.Value=trueyoffset;

            app.yoffset.Value=0;
            app.xoffset.Value=0;

            app.ini.WriteFile('inis/ScreenParams.ini');

        end

        function isGraphicsReady=CheckGraphics(app,howmany)
            if ~exist('howmany','var')
                howmany=1000;
            end
            for i=1:howmany
                try
                    com=matlabUDP_gandhi('receive', app.mhpass.graphicsport);
                    eval(com)
                    while matlabUDP_gandhi('check', app.mhpass.graphicsport)
                        matlabUDP_gandhi('receive', app.mhpass.graphicsport);
                    end
                end
                if exist('isGraphicsReady','var') % checking if graphics are still working
                    if isGraphicsReady==1
                        app.GraphicsLamp.Color=[0,1,0];
                    end
                end
            end
            if ~exist('isGraphicsReady','var')
                app.GraphicsLamp.Color=[1,0,0];
                isGraphicsReady=0;
            elseif isGraphicsReady==0
                app.GraphicsLamp.Color=[1,0,0];
            end

        end

        function filename = logError(app, err, source)
            % Create a timestamped filename for better organization
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            logDir = 'ErrorLogs';

            % Create logs directory if it doesn't exist
            if ~exist(logDir, 'dir')
                mkdir(logDir);
            end

            % Create a descriptive filename
            filename = fullfile(logDir, sprintf('Error_%s_%s.log', source, timestamp));

            % Open file
            fid = fopen(filename, 'w');

            % Write formatted header
            fprintf(fid, '=================================================================\n');
            fprintf(fid, '  ERROR LOG: %s\n', datestr(now));
            fprintf(fid, '  Source: %s\n', source);
            fprintf(fid, '=================================================================\n\n');

            % Write error message
            fprintf(fid, 'ERROR MESSAGE:\n');
            fprintf(fid, '-----------------------------------------------------------------\n');
            fprintf(fid, '%s\n\n', err.message);

            % Write stack trace in a structured way
            fprintf(fid, 'STACK TRACE:\n');
            fprintf(fid, '-----------------------------------------------------------------\n');
            for i = 1:length(err.stack)
                fprintf(fid, '%d. In function: %s (line %d)\n', i, err.stack(i).name, err.stack(i).line);
                fprintf(fid, '   File: %s\n\n', err.stack(i).file);
            end

            % Write system information
            fprintf(fid, 'SYSTEM INFORMATION:\n');
            fprintf(fid, '-----------------------------------------------------------------\n');
            fprintf(fid, 'MATLAB Version: %s\n', version);
            fprintf(fid, 'Operating System: %s\n', computer);
            fprintf(fid, 'User: %s\n\n', getenv('USER'));

            % Write application state if available
            fprintf(fid, 'APPLICATION STATE:\n');
            fprintf(fid, '-----------------------------------------------------------------\n');
            fprintf(fid, 'Running: %d\n', app.running);
            fprintf(fid, 'Trial number: %d\n', app.mhpass.trialnumpersistent);
            fprintf(fid, 'Subject: %s\n', app.SubjectNameEditField.Value);
            fprintf(fid, 'Parameter file: %s\n', app.ParameterFile.Value);

            % Close the file
            fclose(fid);

            % Add error to app's information text area
            app.insToTxtbox(sprintf('Error occurred in %s. See %s for details.', source, filename));
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            warning('off','all') % suppress warnings like UDP

            app.ClearHiddenFolders(1,1)

            app.filepaths.ReadFile(app.filepaths_path);
            addpath(genpath(app.filepaths.GetValues('paths','xippmex')));
            movegui(app.UIFigure,[1100 100]);

            evalin('base','clear'); %clear world
            warning('off','MATLAB:structOnObject'); %remove an annoying warning

            funpath=which(mfilename);
            cd(fileparts(funpath)); %switch to the filepath of the app
            
            app.homepath=genpath(app.filepaths.GetValues('paths','home'));
            addpath(genpath(app.filepaths.GetValues('paths','home')));

            app.LiveParameters = LiveParams(app); %launch params window

            %% set up daq. Modify the specifics in the setupDAQ function
            setupDAQ(app);
            app.chidx=xippmex('elec','analog');

            %% start the mh structure
            mh=internal;
            mh.runtrial=1;
            mh.graphicsport = matlabUDP_gandhi('open', '127.0.0.1', '127.0.0.2', 2020); %start udp port %start udp port
            disp('1192')
            mh.rewardport = udpport("LocalPort",2024, "Timeout",0.001); %start udp port
            app.mhpass=mh;

            %% set up initial conditions from previous session
            isini=app.ini.ReadFile('inis/ScreenParams.ini');

            if ~isini
                errordlg('ini not found. Missing or in the wrong path.')
            elseif isini
                app.xoffset.Value=0;
                app.Rawxoffset.Value=app.ini.GetValues('eye calibration','xoffset');
                app.xgain.Value=app.ini.GetValues('eye calibration','xgain');
                app.yoffset.Value=0;
                app.Rawyoffset.Value=app.ini.GetValues('eye calibration','yoffset');
                app.ygain.Value=app.ini.GetValues('eye calibration','ygain');
                app.RewardDuration.Value=app.ini.GetValues('reward','reward');

                app.Dir.Value = app.ini.GetValues('last filepaths','data');
                app.ParameterFile.Value = app.ini.GetValues('last filepaths','params');
                try
                    copyfile(fullfile(app.ParameterFile.Value),'.Parameters_Internal')
                catch
                    app.insToTxtbox('Parameter file not specified. Select parameter file')
                    [file,path] = uigetfile('~/Documents','select parameter file');
                    set(app.ParameterFile,'Value',fullfile(path,file))
                    copyfile(fullfile(path,file),'.Parameters_Internal')
                end
                app.TrellisDir.Value = app.ini.GetValues('last filepaths','trellis');

                mh.eccentricity_gain = app.ini.GetValues('target window parameters','eccentricity_gain');
                mh.trailing_window_time = app.ini.GetValues('target window parameters','trailing_window_time');
            end


            %% put screen params into mh
            % mh.screenparams.xPixelSize=app.ini.GetValues('for deg2pix','xPixelSize');
            % mh.screenparams.yPixelSize=app.ini.GetValues('for deg2pix','yPixelSize');
            % mh.screenparams.true_center=app.ini.GetValues('for deg2pix','true center');
            % mh.screenparams.subject_distance=app.ini.GetValues('for deg2pix','subject distance');



            %% check if the filepaths are empty
            if strcmp(app.Dir.Value,'null') || isempty(app.Dir.Value)
                app.insToTxtbox('data directory is empty. Select data directory')
                dir=uigetdir('~/Documents','select folder for data');
                set(app.Dir,'Value',dir)
            end

            while app.paramsloaded == 0
                try
                    app.makeparams
                    app.paramsloaded=1;
                catch err
                    app.errored=1;
                    logError(app, err, 'app.paramsloaded');
                    app.insToTxtbox('Could not load parameters, possible errors inside the file.')

                    app.ClearHiddenFolders(0,0)
                    [file,path] = uigetfile('~/Documents','select parameter file');
                    set(app.ParameterFile,'Value',fullfile(path,file))
                    copyfile(fullfile(path,file),'.Parameters_Internal')
                    app.idle_loop;
                end
            end

            %% check if graphics are already up
            isGraphicsReady=app.CheckGraphics(5);

            %% launch reward handler
            system(['gnome-terminal --tab -- sh -c "', app.filepaths.GetValues('paths','reward_handler'),' ',   app.filepaths.GetValues('paths','runtime'), '" --title="reward handler"']);
            %% launch sound handler
            system(['gnome-terminal --tab -- sh -c "', app.filepaths.GetValues('paths','sound_generator'),' ',   app.filepaths.GetValues('paths','runtime'), '" --title="sound"']);
            %% graphics go brrrrrr
            if ~isGraphicsReady
                system('gnome-terminal --tab -- sh -c "cd ./background_functions/; matlab -nodesktop -r ''GraphicsHandler''"');
            end

            system('gnome-terminal -- sh -c "renice -n -18 -p $(pgrep ^graphics)"');


            %% start flipping screens so we can see the eye
            mh.eye=eyeinfo;
            %%wait for graphics to finish launching
            isGraphicsReady=0;
            while ~isGraphicsReady
                isGraphicsReady=app.CheckGraphics(5);
            end
            app.insToTxtbox('ready')

            set(app.FinalizeButton,'Enable','off')

            %% for mh passing between functions
            app.mhpass=mh;
            clc
            system('clear');
            disp('-----Trial Handler-----')
            try %app throws error here when closed
                app.idle_loop;
            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)

            app.addnewoffsets

            app.ini.ReadFile('inis/ScreenParams.ini');

            app.ini.SetValues('reward','reward',...
                app.RewardDuration.Value);

            app.ini.SetValues('last filepaths',{'params','trellis'},...
                {app.ParameterFile.Value,...
                 app.TrellisDir.Value});

            app.ini.WriteFile('inis/ScreenParams.ini');
            sca;
            for i=1:50
            app.mhpass.evalgraphics('exit')
            pause(0.001)
            end

            writeline(app.mhpass.rewardport,'app.UIFigureCloseRequest','0.0.0.0',2025);
            app.mhpass.reward(0,2);
            app.ClearHiddenFolders(1,1);

            delete(app);
            close all force
            quit
        end

        % Button pushed function: FinalizeButton
        function FinalizeButtonPushed(app, event)

            app.insToTxtbox('combining data')
            pause(1)% let it display the thing
            %move temp files in

            dirname=app.checkForDataDirectory;
            load(fullfile(dirname,'e.mat'));
            finfo=dir(fullfile(dirname,'temptrials','*.mat'));
            laodingbar=waitbar(0,'Combining data structure.','Position',[800 400 270 50]);
            for i=1:length(finfo)
                waitbar(i/length(finfo));
                temptrial=load(fullfile(dirname,'temptrials',finfo(i).name));
                e.trial(i)=struct(temptrial.(finfo(i).name(1:end-4)));
                clear temptrial
                delete(fullfile(dirname,'temptrials',finfo(i).name))
            end
            close(laodingbar)
            delete(fullfile(dirname,'temptrials',finfo(1).name))
            save(fullfile(dirname,'e.mat'),'e')
            rmdir(fullfile(dirname,'temptrials'))
            app.checkForDataDirectory = [];

            %iterate folders and move
            dirname=char(dirname); %so you can index it
            addon=length(dir(append(dirname(1:end-5),'*')));
            newdirname=append(dirname(1:end-4), num2str(addon));
            mkdir(newdirname)
            movefile(append(dirname,'/*'),newdirname)

            rmdir(dirname,'s')

            app.addnewoffsets

            app.ini.ReadFile('inis/ScreenParams.ini');

            app.ini.SetValues('reward','reward',...
                app.RewardDuration.Value);

            app.ini.SetValues('last filepaths',{'params'},...
                {app.ParameterFile.Value});

            app.ini.WriteFile('inis/ScreenParams.ini');

            app.insToTxtbox('data combined');
            sca;
        end

        % Button pushed function: STARTButton
        function STARTButtonPushed(app, event)
            app.running=1;
            pause(0.1)% pause to let mh to be assigned in

            app.insToTxtbox('Starting trials')
            app.STARTButton.Enable='off';
            app.SubjectNameEditField.Editable = 'off';

            mh=app.mhpass;
            Run_Experiment(app,mh);

            app.STARTButton.Enable='on';

            app.SubjectNameEditField.Editable = 'on';
        end

        % Value changed function: STOPButton
        function STOPButtonValueChanged(app, event)
            value = app.STOPButton.Value;
            if value==1
                app.insToTxtbox('stopping trials please wait')
            end
        end

        % Button pushed function: LocalDataDirButton
        function LocalDataDirButtonPushed(app, event)
            dir=uigetdir('~/Documents');
            set(app.Dir,'Value',dir)
        end

        % Callback function
        function LoadLatestParamsButtonPushed(app, event)
            fileList=dir(fullfile(app.Dir.Value,'*.zip'));
            [~,idx] = sort([fileList.datenum],'descend');
            fileList = fileList(idx);

            fpath=fullfile(fileList(1).folder,fileList(1).name);

            app.insToTxtbox(['loading parameters from: ' fileList(1).name])

            app.getParams(fpath)
        end

        % Menu selected function: ScreenInfoMenu
        function ScreenInfoMenuSelected(app, event)
            ScreenInfo(app)
        end

        % Button pushed function: ResetAutoCalibrationButton
        function ResetAutoCalibrationButtonPushed(app, event)
            mh=app.mhpass;
            mh.autocalibrationmatrix=[];
            mh.autocalibrationmatrix_buffer=[];
            mh.autocalibrationtrials=0;
            app.AutoCalibTrials.Value=mh.autocalibrationtrials;
            app.mhpass=mh;
        end

        % Menu selected function: EnterDebugMenu
        function EnterDebugMenuSelected(app, event)
            keyboard
        end

        % Key press function: UIFigure
        function UIFigureKeyPress(app, event)
            key = event.Key;
            mh=app.mhpass;
            if strcmp(key,'shift')
                mh.reward(app.RewardDuration.Value);
            end
        end

        % Value changed function: UseAutoCalibrationValuesButton
        function UseAutoCalibrationValuesButtonValueChanged(app, event)
            if app.UseAutoCalibrationValuesButton.Value == 1
                mh=app.mhpass;
                if size(mh.autocalibrationmatrix,1)<3
                    % msgbox('Less than 3 unique targets recorded. Will not autocalibrate')
                    app.UseAutoCalibrationValuesButton.Value = 0;
                else
                    app.xgain.Value = app.xgainauto.Value;
                    app.xoffset.Value = app.xoffsetauto.Value;
                    app.ygain.Value = app.ygainauto.Value;
                    app.yoffset.Value = app.yoffsetauto.Value;

                    app.UseAutoCalibrationValuesButton.Value = 0;
                end
            end
        end

        % Menu selected function: ResetGraphicsMenu
        function ResetGraphicsMenuSelected(app, event)
            WARNING=questdlg('restart graphics handler?', ...
                'graphics', ...
                'yes','no','yes');
            switch WARNING
                case 'yes'
                    tic
                    graphics_reset_successfully=0;
                    if toc<5000
                        app.mhpass.evalgraphics('exit')
                        %% check if graphics are already up
                        isGraphicsReady=app.CheckGraphics(2);

                        %% graphics go brrrrrr
                        if ~isGraphicsReady && graphics_reset_successfully==0
                            system('gnome-terminal --tab -- sh -c "cd ./background_functions/;matlab -nodesktop -r ''GraphicsHandler''"');
                            graphics_reset_successfully=1;
                        end
                    else
                        if graphics_reset_successfully==0
                            app.insToTxtbox('Could not verify that the graphics handler shut down. Trying to launch a new instance anyway. Perhaps try killing the graphics handler process manually.')
                            system('gnome-terminal --tab -- sh -c "cd ./background_functions/; matlab -nodesktop -r ''GraphicsHandler''"');
                        end
                    end

                    % system('gnome-terminal -- sh -c "renice -n -18 -p $(pgrep ^MATLAB)"');

                case 'no'
                    %do nothing
            end
        end

        % Menu selected function: SpikeMonitorMenu
        function SpikeMonitorMenuSelected(app, event)
            app.spikemonitor = SpikeMonitor(app.mhpass);
            app.spikemonitor.mh=app.mhpass;
        end

        % Button pushed function: ParameterFileButton
        function ParameterFileButtonPushed(app, event)
            app.ClearHiddenFolders(0,0)
            [file,path] = uigetfile('~/Documents','select parameter file');
            set(app.ParameterFile,'Value',fullfile(path,file))
            copyfile(fullfile(path,file),'.Parameters_Internal')
            app.makeparams
        end

        % Button pushed function: TrellisDataDirButton
        function TrellisDataDirButtonPushed(app, event)
            dirstr=uigetdir('/run/user/1000/gvfs/');
            pat='share=';
            patidx = strfind(dirstr,pat);
            dir=dirstr(patidx+7:end);
            set(app.TrellisDir,'Value',dir)
        end

        % Value changed function: TrellisDir
        function TrellisDirValueChanged(app, event)
            %removed code
        end

        % Value changed function: ParameterFile
        function ParameterFileValueChanged(app, event)
            copyfile(fullfile(app.ParameterFile.Value),'.Parameters_Internal')
            app.makeparams
        end

        % Menu selected function: ImportCustomFunctionsMenu
        function ImportCustomFunctionsMenuSelected(app, event)
            dir=uigetdir('~/Documents','select the folder with tasks');
            copyfile(fullfile(dir),'.Custom_Functions')
        end

        % Menu selected function: LiveAnalysisMenu
        function LiveAnalysisMenuSelected(app, event)
            system('gnome-terminal --tab -- sh -c "/usr/LiveAnalysis/application/run_LiveAnalysis.sh /usr/local/MATLAB/MATLAB_Runtime/R2024a" --title="Live analysis handler"');
        end

        % Button pushed function: SeteyelinkparametersButton
        function SeteyelinkparametersButtonPushed(app, event)
            app.ini.ReadFile('inis/ScreenParams.ini');

            app.ini.SetValues('eye calibration',{'xoffset','yoffset',},...
                {num2str(app.Rawxoffset.Value), num2str(app.Rawyoffset.Value)});

            app.ini.WriteFile('inis/ScreenParams.ini');
        end

        % Button pushed function: ZoomInButton
        function ZoomInButtonPushed(app, event)
            matlabUDP_gandhi('send', app.mhpass.graphicsport, 'executegr.scalefactor=0.9;');
        end

        % Button pushed function: ZoomOutButton
        function ZoomOutButtonPushed(app, event)
            matlabUDP_gandhi('send', app.mhpass.graphicsport, 'executegr.scalefactor=1.1;');
        end

        % Button pushed function: ResetZoomButton
        function ResetZoomButtonPushed(app, event)
            matlabUDP_gandhi('send', app.mhpass.graphicsport, 'executeScreen(''PanelFitter'', gr.window_monitor,gr.original_monitor_params);');
        end

        % Button pushed function: LeftButton
        function LeftButtonPushed(app, event)
            matlabUDP_gandhi('send', app.mhpass.graphicsport, 'executegr.left_right=20;');
        end

        % Button pushed function: RightButton
        function RightButtonPushed(app, event)
            matlabUDP_gandhi('send', app.mhpass.graphicsport, 'executegr.left_right=-20;');
        end

        % Button pushed function: DownButton
        function DownButtonPushed(app, event)
            matlabUDP_gandhi('send', app.mhpass.graphicsport, 'executegr.up_down=20;');
        end

        % Button pushed function: UpButton
        function UpButtonPushed(app, event)
            matlabUDP_gandhi('send', app.mhpass.graphicsport, 'executegr.up_down=-20;');
        end

        % Button pushed function: SetGuidesButton
        function SetGuidesButtonPushed(app, event)
            circ=num2str(app.CircleguidesdegreesEditField.Value);
            fontsize=num2str(app.FontsizeEditField.Value);

            commandstring=join(['executegr.circleadder=', ...
                circ,';',...
                'gr.toconvert=[];',...
                'gr.toconvert(:,1)=',...
                app.XYguidelinesEditField.Value,';',...
                'gr.toconvert(:,2)=',...
                app.XYguidelinesEditField.Value,';',...
                'gr.fontsize=',...
                fontsize,';']);
            matlabUDP_gandhi('send', app.mhpass.graphicsport, commandstring);
        end

        % Value changed function: RewardDuration
        function RewardDurationValueChanged(app, event)
            value = app.RewardDuration.Value;
            app.ini.ReadFile('inis/ScreenParams.ini');

            app.ini.SetValues('reward','reward',...
                value);

            app.ini.WriteFile('inis/ScreenParams.ini');
        end

        % Menu selected function: SoundGeneratorMenu
        function SoundGeneratorMenuSelected(app, event)
            system(['gnome-terminal --tab -- sh -c "', app.filepaths.GetValues('paths','sound_generator'),' ',   app.filepaths.GetValues('paths','runtime'), '" --title="sound"']);
            disp('trying to open sound')
        end

        % Button pushed function: ImportPrametersButton
        function ImportPrametersButtonPushed(app, event)
            mh=app.mhpass;
            [file,path] = uigetfile('~/Documents','select dataset');
            loaded=load(fullfile(path,file));
            tempmh = struct(mh);
            propertiestopullout=fields(loaded.e.trial(end).System_Properties);
            for propnumber =1:length(propertiestopullout)
                mh.(propertiestopullout{propnumber})=...
                    loaded.e.trial(end).System_Properties.(propertiestopullout{propnumber});
            end
            for i=1:size(app.LiveParameters.FilesTable.Data,1); app.LiveParameters.FilesTable.Data{i,2}=...
                    mh.ttypeslogic{i,2};
            end
            app.LiveParameters.TargetsTable.Data=mh.targtable;
            app.LiveParameters.IntervalsTable.Data=mh.intervaltable;

            app.mhpass=mh;
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            app.TotalrewardsEditField.Value=0;
        end

        % Callback function
        function FilepathsMenuSelected(app, event)
            filepaths=uigetfile();
        end

        % Menu selected function: ExitMenu
        function ExitMenuSelected(app, event)
            app.UIFigureCloseRequest;
        end

        % Button pushed function: Button
        function ButtonPushed(app, event)
            trinfo=xippmex('trial');
            pathNoName=regexprep(trinfo.filebase, '[/\\][^/\\]*$', '');
            app.TrellisDir.Value=pathNoName;
        end

        % Button pushed function: resetsuccessButton
        function resetsuccessButtonPushed(app, event)
            app.success_counter = 0;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [496 496 724 623];
            app.UIFigure.Name = ' ';
            app.UIFigure.Resize = 'off';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.KeyPressFcn = createCallbackFcn(app, @UIFigureKeyPress, true);

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create ImportCustomFunctionsMenu
            app.ImportCustomFunctionsMenu = uimenu(app.FileMenu);
            app.ImportCustomFunctionsMenu.MenuSelectedFcn = createCallbackFcn(app, @ImportCustomFunctionsMenuSelected, true);
            app.ImportCustomFunctionsMenu.Text = 'Import Custom Functions';

            % Create EnterDebugMenu
            app.EnterDebugMenu = uimenu(app.FileMenu);
            app.EnterDebugMenu.MenuSelectedFcn = createCallbackFcn(app, @EnterDebugMenuSelected, true);
            app.EnterDebugMenu.Text = 'Enter Debug';

            % Create ExitMenu
            app.ExitMenu = uimenu(app.FileMenu);
            app.ExitMenu.MenuSelectedFcn = createCallbackFcn(app, @ExitMenuSelected, true);
            app.ExitMenu.Text = 'Exit';

            % Create UtilsMenu
            app.UtilsMenu = uimenu(app.UIFigure);
            app.UtilsMenu.Text = 'Utils';

            % Create ScreenInfoMenu
            app.ScreenInfoMenu = uimenu(app.UtilsMenu);
            app.ScreenInfoMenu.MenuSelectedFcn = createCallbackFcn(app, @ScreenInfoMenuSelected, true);
            app.ScreenInfoMenu.Text = 'Screen Info';

            % Create ResetGraphicsMenu
            app.ResetGraphicsMenu = uimenu(app.UtilsMenu);
            app.ResetGraphicsMenu.MenuSelectedFcn = createCallbackFcn(app, @ResetGraphicsMenuSelected, true);
            app.ResetGraphicsMenu.Text = 'Reset Graphics';

            % Create SpikeMonitorMenu
            app.SpikeMonitorMenu = uimenu(app.UtilsMenu);
            app.SpikeMonitorMenu.MenuSelectedFcn = createCallbackFcn(app, @SpikeMonitorMenuSelected, true);
            app.SpikeMonitorMenu.Text = 'Spike Monitor';

            % Create LiveAnalysisMenu
            app.LiveAnalysisMenu = uimenu(app.UtilsMenu);
            app.LiveAnalysisMenu.MenuSelectedFcn = createCallbackFcn(app, @LiveAnalysisMenuSelected, true);
            app.LiveAnalysisMenu.Text = 'Live Analysis';

            % Create SoundGeneratorMenu
            app.SoundGeneratorMenu = uimenu(app.UtilsMenu);
            app.SoundGeneratorMenu.MenuSelectedFcn = createCallbackFcn(app, @SoundGeneratorMenuSelected, true);
            app.SoundGeneratorMenu.Text = 'Sound Generator';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [379 48 328 406];

            % Create eyeTab
            app.eyeTab = uitab(app.TabGroup);
            app.eyeTab.Title = 'eye';

            % Create EyeCalibrationPanel
            app.EyeCalibrationPanel = uipanel(app.eyeTab);
            app.EyeCalibrationPanel.TitlePosition = 'centertop';
            app.EyeCalibrationPanel.Title = 'Eye Calibration ';
            app.EyeCalibrationPanel.Position = [15 11 300 356];

            % Create AutoCalibrationLabel
            app.AutoCalibrationLabel = uilabel(app.EyeCalibrationPanel);
            app.AutoCalibrationLabel.HorizontalAlignment = 'center';
            app.AutoCalibrationLabel.Position = [197 298 62 30];
            app.AutoCalibrationLabel.Text = {'Auto '; 'Calibration'};

            % Create xgainauto
            app.xgainauto = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.xgainauto.Editable = 'off';
            app.xgainauto.Position = [203 265 45 22];

            % Create xoffsetauto
            app.xoffsetauto = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.xoffsetauto.Editable = 'off';
            app.xoffsetauto.Position = [203 224 45 22];

            % Create ygainauto
            app.ygainauto = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.ygainauto.Editable = 'off';
            app.ygainauto.Position = [202 185 45 22];

            % Create yoffsetauto
            app.yoffsetauto = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.yoffsetauto.Editable = 'off';
            app.yoffsetauto.Position = [203 145 45 22];

            % Create UniqueTargetsEditField
            app.UniqueTargetsEditField = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.UniqueTargetsEditField.Editable = 'off';
            app.UniqueTargetsEditField.Tooltip = {'Unique targets in auto calibration buffer'};
            app.UniqueTargetsEditField.Position = [190 106 29 22];

            % Create SetCalibrationButton
            app.SetCalibrationButton = uibutton(app.EyeCalibrationPanel, 'state');
            app.SetCalibrationButton.Text = 'Set Calibration';
            app.SetCalibrationButton.BackgroundColor = [0.6353 0.0784 0.1843];
            app.SetCalibrationButton.FontSize = 18;
            app.SetCalibrationButton.FontWeight = 'bold';
            app.SetCalibrationButton.FontColor = [1 1 1];
            app.SetCalibrationButton.Position = [26 102 142 30];

            % Create ResetAutoCalibrationButton
            app.ResetAutoCalibrationButton = uibutton(app.EyeCalibrationPanel, 'push');
            app.ResetAutoCalibrationButton.ButtonPushedFcn = createCallbackFcn(app, @ResetAutoCalibrationButtonPushed, true);
            app.ResetAutoCalibrationButton.Interruptible = 'off';
            app.ResetAutoCalibrationButton.Position = [41 48 76 38];
            app.ResetAutoCalibrationButton.Text = {'Reset Auto'; ' Calibration'};

            % Create UseAutoCalibrationValuesButton
            app.UseAutoCalibrationValuesButton = uibutton(app.EyeCalibrationPanel, 'state');
            app.UseAutoCalibrationValuesButton.ValueChangedFcn = createCallbackFcn(app, @UseAutoCalibrationValuesButtonValueChanged, true);
            app.UseAutoCalibrationValuesButton.Text = {'Use Auto Calibration'; 'Values'};
            app.UseAutoCalibrationValuesButton.Position = [126 48 134 38];

            % Create xgainEditFieldLabel
            app.xgainEditFieldLabel = uilabel(app.EyeCalibrationPanel);
            app.xgainEditFieldLabel.HorizontalAlignment = 'right';
            app.xgainEditFieldLabel.Position = [31 265 38 22];
            app.xgainEditFieldLabel.Text = 'x gain';

            % Create xgain
            app.xgain = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.xgain.Position = [77 265 100 22];

            % Create xoffsetEditFieldLabel
            app.xoffsetEditFieldLabel = uilabel(app.EyeCalibrationPanel);
            app.xoffsetEditFieldLabel.HorizontalAlignment = 'right';
            app.xoffsetEditFieldLabel.Position = [25 224 44 22];
            app.xoffsetEditFieldLabel.Text = 'x offset';

            % Create xoffset
            app.xoffset = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.xoffset.Position = [77 224 100 22];

            % Create ygainEditFieldLabel
            app.ygainEditFieldLabel = uilabel(app.EyeCalibrationPanel);
            app.ygainEditFieldLabel.HorizontalAlignment = 'right';
            app.ygainEditFieldLabel.Position = [31 185 38 22];
            app.ygainEditFieldLabel.Text = 'y gain';

            % Create ygain
            app.ygain = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.ygain.Position = [77 185 100 22];

            % Create yoffsetEditFieldLabel
            app.yoffsetEditFieldLabel = uilabel(app.EyeCalibrationPanel);
            app.yoffsetEditFieldLabel.HorizontalAlignment = 'right';
            app.yoffsetEditFieldLabel.Position = [26 145 44 22];
            app.yoffsetEditFieldLabel.Text = 'y offset';

            % Create yoffset
            app.yoffset = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.yoffset.Position = [78 145 100 22];

            % Create AutoCalibTrials
            app.AutoCalibTrials = uieditfield(app.EyeCalibrationPanel, 'numeric');
            app.AutoCalibTrials.Editable = 'off';
            app.AutoCalibTrials.Tooltip = {'Number of trials used for the calibration matrix'};
            app.AutoCalibTrials.Position = [232 106 29 22];

            % Create trialTab
            app.trialTab = uitab(app.TabGroup);
            app.trialTab.Title = 'trial';

            % Create TrialIntervals
            app.TrialIntervals = uitable(app.trialTab);
            app.TrialIntervals.ColumnName = {'Interval'; 'Duration'};
            app.TrialIntervals.RowName = {};
            app.TrialIntervals.Position = [17 26 302 192];

            % Create TrialTargets
            app.TrialTargets = uitable(app.trialTab);
            app.TrialTargets.ColumnName = {'Target'; 'Location'; 'Speed'; 'Direction'};
            app.TrialTargets.RowName = {};
            app.TrialTargets.Position = [16 227 302 110];

            % Create TrialnameEditField
            app.TrialnameEditField = uieditfield(app.trialTab, 'text');
            app.TrialnameEditField.Editable = 'off';
            app.TrialnameEditField.HorizontalAlignment = 'center';
            app.TrialnameEditField.Position = [15 349 303 22];

            % Create eyelinkTab
            app.eyelinkTab = uitab(app.TabGroup);
            app.eyelinkTab.Title = 'eyelink';

            % Create RawxoffsetEditFieldLabel
            app.RawxoffsetEditFieldLabel = uilabel(app.eyelinkTab);
            app.RawxoffsetEditFieldLabel.HorizontalAlignment = 'right';
            app.RawxoffsetEditFieldLabel.Position = [8 235 71 22];
            app.RawxoffsetEditFieldLabel.Text = 'Raw x offset';

            % Create Rawxoffset
            app.Rawxoffset = uieditfield(app.eyelinkTab, 'numeric');
            app.Rawxoffset.Position = [94 235 100 22];

            % Create RawyoffsetEditFieldLabel
            app.RawyoffsetEditFieldLabel = uilabel(app.eyelinkTab);
            app.RawyoffsetEditFieldLabel.HorizontalAlignment = 'right';
            app.RawyoffsetEditFieldLabel.Position = [8 205 71 22];
            app.RawyoffsetEditFieldLabel.Text = 'Raw y offset';

            % Create Rawyoffset
            app.Rawyoffset = uieditfield(app.eyelinkTab, 'numeric');
            app.Rawyoffset.Position = [94 205 100 22];

            % Create SeteyelinkparametersButton
            app.SeteyelinkparametersButton = uibutton(app.eyelinkTab, 'push');
            app.SeteyelinkparametersButton.ButtonPushedFcn = createCallbackFcn(app, @SeteyelinkparametersButtonPushed, true);
            app.SeteyelinkparametersButton.Position = [76 174 138 23];
            app.SeteyelinkparametersButton.Text = 'Set eyelink parameters';

            % Create monitorTab
            app.monitorTab = uitab(app.TabGroup);
            app.monitorTab.Title = 'monitor';

            % Create UpButton
            app.UpButton = uibutton(app.monitorTab, 'push');
            app.UpButton.ButtonPushedFcn = createCallbackFcn(app, @UpButtonPushed, true);
            app.UpButton.Position = [171 271 43 23];
            app.UpButton.Text = 'Up';

            % Create RightButton
            app.RightButton = uibutton(app.monitorTab, 'push');
            app.RightButton.ButtonPushedFcn = createCallbackFcn(app, @RightButtonPushed, true);
            app.RightButton.Position = [221 243 43 23];
            app.RightButton.Text = 'Right';

            % Create DownButton
            app.DownButton = uibutton(app.monitorTab, 'push');
            app.DownButton.ButtonPushedFcn = createCallbackFcn(app, @DownButtonPushed, true);
            app.DownButton.Position = [170 218 46 23];
            app.DownButton.Text = 'Down';

            % Create LeftButton
            app.LeftButton = uibutton(app.monitorTab, 'push');
            app.LeftButton.ButtonPushedFcn = createCallbackFcn(app, @LeftButtonPushed, true);
            app.LeftButton.Position = [123 243 43 23];
            app.LeftButton.Text = 'Left';

            % Create ZoomInButton
            app.ZoomInButton = uibutton(app.monitorTab, 'push');
            app.ZoomInButton.ButtonPushedFcn = createCallbackFcn(app, @ZoomInButtonPushed, true);
            app.ZoomInButton.Position = [55 265 43 23];
            app.ZoomInButton.Text = '+';

            % Create ZoomOutButton
            app.ZoomOutButton = uibutton(app.monitorTab, 'push');
            app.ZoomOutButton.ButtonPushedFcn = createCallbackFcn(app, @ZoomOutButtonPushed, true);
            app.ZoomOutButton.Position = [54 230 43 23];
            app.ZoomOutButton.Text = '-';

            % Create AdjustthiswhentrialsarestoppedLabel
            app.AdjustthiswhentrialsarestoppedLabel = uilabel(app.monitorTab);
            app.AdjustthiswhentrialsarestoppedLabel.FontSize = 18;
            app.AdjustthiswhentrialsarestoppedLabel.Position = [24 330 282 23];
            app.AdjustthiswhentrialsarestoppedLabel.Text = 'Adjust this when trials are stopped';

            % Create ResetZoomButton
            app.ResetZoomButton = uibutton(app.monitorTab, 'push');
            app.ResetZoomButton.ButtonPushedFcn = createCallbackFcn(app, @ResetZoomButtonPushed, true);
            app.ResetZoomButton.Position = [115 174 80 23];
            app.ResetZoomButton.Text = 'Reset Zoom';

            % Create CircleguidesdegreesEditFieldLabel
            app.CircleguidesdegreesEditFieldLabel = uilabel(app.monitorTab);
            app.CircleguidesdegreesEditFieldLabel.HorizontalAlignment = 'right';
            app.CircleguidesdegreesEditFieldLabel.Position = [35 126 121 22];
            app.CircleguidesdegreesEditFieldLabel.Text = 'Circle guides degrees';

            % Create CircleguidesdegreesEditField
            app.CircleguidesdegreesEditField = uieditfield(app.monitorTab, 'numeric');
            app.CircleguidesdegreesEditField.Position = [171 126 100 22];
            app.CircleguidesdegreesEditField.Value = 10;

            % Create SetGuidesButton
            app.SetGuidesButton = uibutton(app.monitorTab, 'push');
            app.SetGuidesButton.ButtonPushedFcn = createCallbackFcn(app, @SetGuidesButtonPushed, true);
            app.SetGuidesButton.Position = [120 26 100 23];
            app.SetGuidesButton.Text = 'Set Guides';

            % Create XYguidelinesEditFieldLabel
            app.XYguidelinesEditFieldLabel = uilabel(app.monitorTab);
            app.XYguidelinesEditFieldLabel.HorizontalAlignment = 'right';
            app.XYguidelinesEditFieldLabel.Position = [75 96 82 22];
            app.XYguidelinesEditFieldLabel.Text = 'XY guide lines';

            % Create XYguidelinesEditField
            app.XYguidelinesEditField = uieditfield(app.monitorTab, 'text');
            app.XYguidelinesEditField.HorizontalAlignment = 'right';
            app.XYguidelinesEditField.Position = [172 96 100 22];
            app.XYguidelinesEditField.Value = '[-40:10:40]';

            % Create FontsizeEditFieldLabel
            app.FontsizeEditFieldLabel = uilabel(app.monitorTab);
            app.FontsizeEditFieldLabel.HorizontalAlignment = 'right';
            app.FontsizeEditFieldLabel.Position = [103 67 54 22];
            app.FontsizeEditFieldLabel.Text = 'Font size';

            % Create FontsizeEditField
            app.FontsizeEditField = uieditfield(app.monitorTab, 'numeric');
            app.FontsizeEditField.Position = [172 67 100 22];
            app.FontsizeEditField.Value = 30;

            % Create miscTab
            app.miscTab = uitab(app.TabGroup);
            app.miscTab.Title = 'misc';

            % Create Trials_without_recording_counter
            app.Trials_without_recording_counter = uieditfield(app.miscTab, 'numeric');
            app.Trials_without_recording_counter.Tooltip = {'How many trials alowed without neural recording'};
            app.Trials_without_recording_counter.Position = [176 336 24 22];
            app.Trials_without_recording_counter.Value = 25;

            % Create TrialswithoutneuraldataLabel
            app.TrialswithoutneuraldataLabel = uilabel(app.miscTab);
            app.TrialswithoutneuraldataLabel.Position = [17 336 139 22];
            app.TrialswithoutneuraldataLabel.Text = 'Trials without neural data';

            % Create RepeatfailedtrialsEditFieldLabel
            app.RepeatfailedtrialsEditFieldLabel = uilabel(app.miscTab);
            app.RepeatfailedtrialsEditFieldLabel.HorizontalAlignment = 'right';
            app.RepeatfailedtrialsEditFieldLabel.Position = [15 297 104 22];
            app.RepeatfailedtrialsEditFieldLabel.Text = 'Repeat failed trials';

            % Create RepeatfailedtrialsEditField
            app.RepeatfailedtrialsEditField = uieditfield(app.miscTab, 'numeric');
            app.RepeatfailedtrialsEditField.Position = [176 297 24 22];
            app.RepeatfailedtrialsEditField.Value = 2;

            % Create resetsuccessButton
            app.resetsuccessButton = uibutton(app.miscTab, 'push');
            app.resetsuccessButton.ButtonPushedFcn = createCallbackFcn(app, @resetsuccessButtonPushed, true);
            app.resetsuccessButton.Position = [16 259 100 23];
            app.resetsuccessButton.Text = 'reset success';

            % Create SubjectNameEditFieldLabel
            app.SubjectNameEditFieldLabel = uilabel(app.UIFigure);
            app.SubjectNameEditFieldLabel.HorizontalAlignment = 'right';
            app.SubjectNameEditFieldLabel.Position = [30 587 81 22];
            app.SubjectNameEditFieldLabel.Text = 'Subject Name';

            % Create SubjectNameEditField
            app.SubjectNameEditField = uieditfield(app.UIFigure, 'text');
            app.SubjectNameEditField.Position = [126 587 121 22];
            app.SubjectNameEditField.Value = 'NAME';

            % Create Dir
            app.Dir = uieditfield(app.UIFigure, 'text');
            app.Dir.Position = [30 554 384 22];

            % Create LocalDataDirButton
            app.LocalDataDirButton = uibutton(app.UIFigure, 'push');
            app.LocalDataDirButton.ButtonPushedFcn = createCallbackFcn(app, @LocalDataDirButtonPushed, true);
            app.LocalDataDirButton.Position = [425 554 93 23];
            app.LocalDataDirButton.Text = 'Local Data Dir';

            % Create ParameterFile
            app.ParameterFile = uieditfield(app.UIFigure, 'text');
            app.ParameterFile.ValueChangedFcn = createCallbackFcn(app, @ParameterFileValueChanged, true);
            app.ParameterFile.Position = [30 515 384 22];

            % Create ParameterFileButton
            app.ParameterFileButton = uibutton(app.UIFigure, 'push');
            app.ParameterFileButton.ButtonPushedFcn = createCallbackFcn(app, @ParameterFileButtonPushed, true);
            app.ParameterFileButton.Position = [425 515 94 23];
            app.ParameterFileButton.Text = 'Parameter File';

            % Create TrellisDir
            app.TrellisDir = uieditfield(app.UIFigure, 'text');
            app.TrellisDir.ValueChangedFcn = createCallbackFcn(app, @TrellisDirValueChanged, true);
            app.TrellisDir.Position = [32 475 382 22];

            % Create TrellisDataDirButton
            app.TrellisDataDirButton = uibutton(app.UIFigure, 'push');
            app.TrellisDataDirButton.ButtonPushedFcn = createCallbackFcn(app, @TrellisDataDirButtonPushed, true);
            app.TrellisDataDirButton.Position = [425 475 94 23];
            app.TrellisDataDirButton.Text = 'Trellis Data Dir';

            % Create RECORDNEURALDATACheckBox
            app.RECORDNEURALDATACheckBox = uicheckbox(app.UIFigure);
            app.RECORDNEURALDATACheckBox.Text = 'RECORD NEURAL DATA';
            app.RECORDNEURALDATACheckBox.FontSize = 18;
            app.RECORDNEURALDATACheckBox.FontColor = [0.6353 0.0784 0.1843];
            app.RECORDNEURALDATACheckBox.Position = [64 153 230 22];
            app.RECORDNEURALDATACheckBox.Value = true;

            % Create InformationTextAreaLabel
            app.InformationTextAreaLabel = uilabel(app.UIFigure);
            app.InformationTextAreaLabel.HorizontalAlignment = 'center';
            app.InformationTextAreaLabel.Position = [162 430 73 24];
            app.InformationTextAreaLabel.Text = 'Information';

            % Create InformationTextArea
            app.InformationTextArea = uitextarea(app.UIFigure);
            app.InformationTextArea.Editable = 'off';
            app.InformationTextArea.Position = [29 184 339 247];
            app.InformationTextArea.Value = {' '};

            % Create STARTButton
            app.STARTButton = uibutton(app.UIFigure, 'push');
            app.STARTButton.ButtonPushedFcn = createCallbackFcn(app, @STARTButtonPushed, true);
            app.STARTButton.Position = [30 107 100 23];
            app.STARTButton.Text = 'START';

            % Create STOPButton
            app.STOPButton = uibutton(app.UIFigure, 'state');
            app.STOPButton.ValueChangedFcn = createCallbackFcn(app, @STOPButtonValueChanged, true);
            app.STOPButton.Enable = 'off';
            app.STOPButton.Text = 'STOP';
            app.STOPButton.Position = [147 107 100 23];

            % Create FinalizeButton
            app.FinalizeButton = uibutton(app.UIFigure, 'push');
            app.FinalizeButton.ButtonPushedFcn = createCallbackFcn(app, @FinalizeButtonPushed, true);
            app.FinalizeButton.Enable = 'off';
            app.FinalizeButton.Position = [269 107 100 23];
            app.FinalizeButton.Text = 'Finalize';

            % Create RewardDuration
            app.RewardDuration = uieditfield(app.UIFigure, 'numeric');
            app.RewardDuration.ValueChangedFcn = createCallbackFcn(app, @RewardDurationValueChanged, true);
            app.RewardDuration.Position = [31 59 100 22];
            app.RewardDuration.Value = 0.5;

            % Create RewardButton
            app.RewardButton = uibutton(app.UIFigure, 'state');
            app.RewardButton.Interruptible = 'off';
            app.RewardButton.Text = 'Reward';
            app.RewardButton.Position = [149 59 100 23];

            % Create StopRewardButton
            app.StopRewardButton = uibutton(app.UIFigure, 'state');
            app.StopRewardButton.Interruptible = 'off';
            app.StopRewardButton.Text = 'Stop Reward';
            app.StopRewardButton.Position = [270 59 100 23];

            % Create XippmexLampLabel
            app.XippmexLampLabel = uilabel(app.UIFigure);
            app.XippmexLampLabel.HorizontalAlignment = 'right';
            app.XippmexLampLabel.Position = [593 554 52 22];
            app.XippmexLampLabel.Text = 'Xippmex';

            % Create XippmexLamp
            app.XippmexLamp = uilamp(app.UIFigure);
            app.XippmexLamp.Position = [660 554 20 20];
            app.XippmexLamp.Color = [1 0 0];

            % Create GraphicsLampLabel
            app.GraphicsLampLabel = uilabel(app.UIFigure);
            app.GraphicsLampLabel.HorizontalAlignment = 'right';
            app.GraphicsLampLabel.Position = [592 515 53 22];
            app.GraphicsLampLabel.Text = 'Graphics';

            % Create GraphicsLamp
            app.GraphicsLamp = uilamp(app.UIFigure);
            app.GraphicsLamp.Position = [660 515 20 20];
            app.GraphicsLamp.Color = [1 0 0];

            % Create ImportPrametersButton
            app.ImportPrametersButton = uibutton(app.UIFigure, 'push');
            app.ImportPrametersButton.ButtonPushedFcn = createCallbackFcn(app, @ImportPrametersButtonPushed, true);
            app.ImportPrametersButton.Position = [266 586 108 23];
            app.ImportPrametersButton.Text = 'Import Prameters';

            % Create TotalrewardsEditFieldLabel
            app.TotalrewardsEditFieldLabel = uilabel(app.UIFigure);
            app.TotalrewardsEditFieldLabel.HorizontalAlignment = 'right';
            app.TotalrewardsEditFieldLabel.Position = [144 18 88 22];
            app.TotalrewardsEditFieldLabel.Text = 'Total reward (s)';

            % Create TotalrewardsEditField
            app.TotalrewardsEditField = uieditfield(app.UIFigure, 'numeric');
            app.TotalrewardsEditField.Position = [32 18 99 22];

            % Create ResetButton
            app.ResetButton = uibutton(app.UIFigure, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Position = [246 18 47 23];
            app.ResetButton.Text = 'Reset';

            % Create Button
            app.Button = uibutton(app.UIFigure, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed, true);
            app.Button.Position = [527 474 29 23];
            app.Button.Text = '⟳';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MHost2_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end