function RewardHandler

system('gnome-terminal --title="reward handler"');
rewardport = udpport("LocalPort",2022);
configureCallback(rewardport,"terminator",@getCommands);
xippmex;
system('clear');
disp('-----Reward Handler-----');

function getCommands(rewardport,~)
    identifier=0;
    duration=readline(rewardport);
    duration = str2num(duration);
    if length(duration) >1
        identifier=duration(2);
        duration=duration(1);
    end
    sound(sin(1:1e6),3000);
    xippmex('digout',3,1);
    tic;
    pause(duration);
    xippmex('digout',3,0);
    flush(rewardport,'input')
    rewamount=toc;
    clear sound
    if identifier==1
        disp(['manually rewarded for ' num2str(rewamount) ' seconds'])
        writeline(rewardport,['app.insToTxtbox("manual reward: ' num2str(rewamount) 's");'],'0.0.0.0',2020);
    elseif identifier==2
        exit
    else
        disp(['rewarded for ' num2str(rewamount) ' seconds'])
        writeline(rewardport,['app.insToTxtbox("reward: ' num2str(rewamount) 's");'],'0.0.0.0',2020);
    end
    pause(0.02); %pause for a bit to not get double rewards
end

while 1 %keep it alive
    pause(0.00001)
end

end

