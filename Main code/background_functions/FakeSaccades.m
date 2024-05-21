function [xpos] = FakeSaccades(degrees,prob,timelength)
%generates a vector of fake generic saccades for code debugging. Very
%rudimentary. The degrees specify just the degrees of each component, not
%obliques.

saccade=(1./(1 + exp(-0.3.*((0:40)-20)))*degrees);

xpos=zeros(1,timelength);
ypos=zeros(1,timelength);

xissaccade=0;
xcount=0;
xreverse=0;

for i=2:timelength
    rollxdice=randi(1000);
    if rollxdice>(prob*1000) && ~xissaccade
        xpos(i)=xpos(i-1);
    else 
        xissaccade=1;
        if ~xreverse
            xcount=xcount+1;
            xpos(i)=saccade(xcount);
        else
            xcount=xcount+1;
            xpos(i)=-saccade(xcount)+degrees;
        end
        if xcount==length(saccade)
            xcount=0;
            xissaccade=0;
            xreverse=~xreverse;
        end
    end
end

