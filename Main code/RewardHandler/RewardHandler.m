function RewardHandler

rewardport = udpport("LocalPort",2022);
configureCallback(rewardport,"terminator",@getCommands);
xippmex;
system('clear');
ini=IniConfig();
warning('off')
rewardcount=0;
disp('-----Reward Handler-----');


while 1 %keep it alive
    try %% error catcher
        ini.ReadFile('/home/gandhi/Documents/MATLAB/Gandhi-PsychToolboxMERGER/Gandhi-PsychToolbox/Main code/inis/ScreenParams.ini');
        manreward=ini.GetValues('reward','reward');
        [~,~,events]=xippmex('digin');
        if ~isempty(events) && any([events.reason]==16) && any([events.sma4]>0)
            try
                sendreward(manreward,3);
            end
        end
        [~,~,~]=xippmex('digin'); %clear digital buffer
        xippmex('digout',3,0);
        pause(0.00001)
    catch e
        disp(e.message)
    end
end
    function getCommands(rewardport,~)
        identifier=0;
        duration=readline(rewardport);
        try
            if ~contains(duration,'dump')
                duration = str2num(duration);
                if length(duration) >1
                    identifier=duration(2);
                    duration=duration(1);
                end
                sendreward(duration, identifier)
            else
                try
                    eval(duration)
                end
            end
        catch

        end
    end

    function sendreward(duration, identifier)
        makesound(duration)
        tstart=getsecs;
        tnow=getsecs;
        tic;
        xippmex('digout',3,1);
        while tnow<(tstart+duration)
            % xippmex('digout',3,1);
            pause(0.001)
            tnow=getsecs;
        end
        xippmex('digout',3,0);
        rewamount=toc;
        flush(rewardport,'input')
        clear sound
        if identifier==1
            disp(['manually (gui) rewarded for ' num2str(rewamount) ' seconds'])
            writeline(rewardport,['app.insToTxtbox("manual reward: ' num2str(rewamount) 's");'],'0.0.0.0',2024);
        elseif identifier==2
            exit
        elseif identifier==3
            disp(['manually (button) rewarded for ' num2str(rewamount) ' seconds'])
            writeline(rewardport,['app.insToTxtbox("manual reward: ' num2str(rewamount) 's");'],'0.0.0.0',2024);
        else
            disp(['rewarded for ' num2str(rewamount) ' seconds'])
            writeline(rewardport,['app.insToTxtbox("reward: ' num2str(rewamount) 's");'],'0.0.0.0',2024);
        end
        writeline(rewardport,['app.TotalrewardsEditField.Value= app.TotalrewardsEditField.Value +' num2str(rewamount) ';'],'0.0.0.0',2024);
        pause(0.02); %pause for a bit to not get double rewards
        rewardcount=rewardcount+rewamount;
    end
    function dumpdata(fname)
        temptr=[];
        trname=[];
        disp('trying to dump data')
        fname=strtrim(fname);
        temptr=load(fname);
        trname=fields(temptr);
        temptr.(trname{:}).reward=temptr.(trname{:}).reward+rewardcount;
        rewardcount=0;
        save(fname,'-struct','temptr');
        disp(join(['saved ',trname{:}]))
    end
    function makesound(dur)
        %MAKESOUND Summary of this function goes here
        %   Detailed explanation goes here
        %% generate command string
        commid=num2str(randi(100));
        tp='1';
        hz='600';
        amp='1';

        commstring=join(['GenerateSound_udp(app,',commid,',', tp,',', num2str(dur),',', amp,',', hz,');']);
        %% send the thing using the reward port
        writeline(rewardport,commstring,'0.0.0.0',2025);
    end
end



