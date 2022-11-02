function [xeye, yeye] = eyepos(w,dq,xin,yin)
    pause (0.0001)

    xy=read(dq,'all','OutputFormat','Matrix');

    if ~isempty(xy)
        xy=mean(xy(end-5:end,:));
    end

  
    try
        xy(2)=-xy(2);
    end

    totalmin=w.minEye;
    totalmax=w.maxEye;
    totaldiff=totalmax-totalmin;
    
    % normalize and multiply by screen size
    try
        x=(xy(1)-totalmin)/(totaldiff);
        y=(xy(2)-totalmin)/(totaldiff);


        xeye=x*w.screenXpixels;
        yeye=y*w.screenYpixels;
    catch
        xeye=xin;
        yeye=yin;
    end

end