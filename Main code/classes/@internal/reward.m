function mh=reward(mh,int)

    if isnumeric(int)
        duration = int;
    else
        duration = int.duration;
    end
    writeline(mh.graphicsport,num2str(duration),'0.0.0.0',2022);
    % app.insToTxtbox(['Requested reward of: ' num2str(getsecs-mh.rew.rewstart) 's']);
end