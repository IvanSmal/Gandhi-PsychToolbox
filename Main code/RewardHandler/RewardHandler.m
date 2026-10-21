function RewardHandler
    % Initialize UDP port with proper error handling
    try
        rewardport = udpport("LocalPort", 2022);
        configureCallback(rewardport, "terminator", @getCommands);
        % MHost2's Stop Reward button. A port of its own, polled rather than
        % given a callback: sendreward runs inside the rewardport callback, so
        % a stop sent to 2022 would only be read after the reward was over.
        stopport = udpport("LocalPort", 2026);
    catch e
        fprintf('Error initializing reward port: %s\n', e.message);
        return;
    end
    
    % Initialize xippmex with error handling
    try
        status = xippmex;
        if status ~= 1
            error('Failed to initialize xippmex');
        end
    catch e
        fprintf('Error initializing xippmex: %s\n', e.message);
        cleanupAndExit(rewardport, stopport);
        return;
    end
    
    system('clear');
    ini = IniConfig();
    warning('off')
    rewardcount = 0;
    disp('-----Reward Handler-----');
    
    % Add cleanup handler for proper resource management
    cleanupObj = onCleanup(@() cleanupAndExit(rewardport, stopport));
    
    while 1 % keep it alive
        try % error catcher
            ini.ReadFile('/home/gandhi/Documents/MATLAB/Gandhi-PsychToolboxMERGER/Gandhi-PsychToolbox/Main code/inis/ScreenParams.ini');
            manreward = ini.GetValues('reward', 'reward');
            [~, ~, events] = xippmex('digin');
            if ~isempty(events) && any([events.reason] == 16) && any([events.sma4] > 0)
                try
                    sendreward(manreward, 3);
                catch e
                    disp(['Error in sendreward: ' e.message]);
                end
            elseif ~isempty(events) && any([events.reason] == 40) && any([events.sma3] > 0)
                try
                    xippmex('digout', 3, 0);
                catch e
                    disp(['Error in stopping reward: ' e.message]);
                end
            end
            if stopRequested() % Stop Reward with no reward running: make sure the valve is shut
                try
                    xippmex('digout', 3, 0);
                catch e
                    disp(['Error in stopping reward: ' e.message]);
                end
            end
            [~, ~, ~] = xippmex('digin'); % clear digital buffer
            
            pause(0.00001)
        catch e
            disp(['Main loop error: ' e.message]);
            pause(0.5)
        end
    end
    
    function getCommands(rewardport, ~)
        try
            identifier = 0;
            duration = readline(rewardport);
            
            if ~contains(duration, 'dump')
                duration = str2num(duration);
                if length(duration) > 1
                    identifier = duration(2);
                    duration = duration(1);
                end
                sendreward(duration, identifier)
            else
                try
                    eval(duration)
                catch evalErr
                    disp(['Error executing command: ' evalErr.message]);
                end
            end
        catch e
            disp(['Command processing error: ' e.message]);
        end
    end
    
    function sendreward(duration, identifier)
        try
            makesound(duration)
            stopRequested(); % drop a stale stop so it cannot cut this reward short
            stopped = false;
            tstart = getsecs;
            tnow = getsecs;
            tic;
            xippmex('digout', 3, 1);
            while tnow < (tstart + duration)
                [~, ~, events] = xippmex('digin');
                if ~isempty(events) && all([events.sma3] == 0)
                    try
                        xippmex('digout', 3, 1);
                    catch e
                        disp(['Error in stopping reward: ' e.message]);
                    end
                end
                if stopRequested()
                    stopped = true;
                    break
                end
                pause(0.001)
                tnow = getsecs;
            end
            xippmex('digout', 3, 0);
            rewamount = toc; % time the valve was actually open
            flush(rewardport, 'input')
            clear sound
            
            note = '';
            if stopped
                note = sprintf(' (stopped early; %gs requested)', duration);
            end

            try
                if identifier == 1
                    disp(['manually (gui) rewarded for ' num2str(rewamount) ' seconds' note])
                    writeline(rewardport, ['app.insToTxtbox("manual reward: ' num2str(rewamount) 's' note '");'], '0.0.0.0', 2024);
                elseif identifier == 2
                    % Properly exit without infinite loop
                    disp('Closing reward handler');
                    cleanupAndExit(rewardport, stopport);
                    quit force;
                elseif identifier == 3
                    disp(['manually (button) rewarded for ' num2str(rewamount) ' seconds' note])
                    writeline(rewardport, ['app.insToTxtbox("manual reward: ' num2str(rewamount) 's' note '");'], '0.0.0.0', 2024);
                else
                    disp(['rewarded for ' num2str(rewamount) ' seconds' note])
                    writeline(rewardport, ['app.insToTxtbox("reward: ' num2str(rewamount) 's' note '");'], '0.0.0.0', 2024);
                end
                
                % Update total rewards
                writeline(rewardport, ['app.TotalrewardsEditField.Value= app.TotalrewardsEditField.Value +' num2str(rewamount) ';'], '0.0.0.0', 2024);
            catch commErr
                disp(['Communication error: ' commErr.message]);
            end
            
            pause(0.02); % pause for a bit to not get double rewards
            rewardcount = rewardcount + rewamount;
        catch e
            disp(['Error in sendreward: ' e.message]);
        end
    end
    
    function dumpdata(fname)
        try
            temptr = [];
            trname = [];
            disp('trying to dump data')
            fname = strtrim(fname);
            temptr = load(fname);
            trname = fields(temptr);
            temptr.(trname{1}).reward = temptr.(trname{1}).reward + rewardcount;
            rewardcount = 0;
            save(fname, '-struct', 'temptr');
            disp(['saved ' trname{1}])
        catch e
            disp(['Error saving data: ' e.message]);
        end
    end
    
    function makesound(dur)
        try
            % Generate command string
            commid = num2str(randi(100));
            tp = '1';
            hz = '600';
            amp = '1';
            
            commstring = ['GenerateSound_udp(app,' commid ',' tp ',' num2str(dur) ',' amp ',' hz ');'];
            % Send using the reward port
            writeline(rewardport, commstring, '0.0.0.0', 2025);
        catch e
            disp(['Error in makesound: ' e.message]);
        end
    end
    
    function tf = stopRequested()
        % True if MHost2 sent Stop Reward since the last check. Everything on
        % this port is a stop, so the content does not matter: drop it.
        tf = stopport.NumBytesAvailable > 0;
        if tf
            flush(stopport, 'input');
        end
    end

    function cleanupAndExit(port, stopPort)
        try
            % Clean up xippmex
            xippmex('close');
        catch
            % Ignore errors during cleanup
        end
        
        try
            % Clean up UDP port
            if isvalid(port)
                configureCallback(port, "off");
                flush(port);
                delete(port);
            end
        catch
            % Ignore errors during cleanup
        end

        try
            if isvalid(stopPort)
                delete(stopPort);
            end
        catch
            % Ignore errors during cleanup
        end
    end
end