function [xPos] = FakeSaccades(degrees,saccadeProb,nSamples)
%generates a vector of fake generic saccades for code debugging. Very
%rudimentary. The degrees specify just the degrees of each component, not
%obliques.

saccadeProfile=(1./(1 + exp(-0.3.*((0:40)-20)))*degrees);

xPos=zeros(1,nSamples);
yPos=zeros(1,nSamples);

xIsSaccade=0;
xCount=0;
xReverse=0;

for iSample=2:nSamples
    xDiceRoll=randi(1000);
    if xDiceRoll>(saccadeProb*1000) && ~xIsSaccade
        xPos(iSample)=xPos(iSample-1)+normrnd(0,0.01);
    else 
        xIsSaccade=1;
        if ~xReverse
            xCount=xCount+1;
            xPos(iSample)=saccadeProfile(xCount);
        else
            xCount=xCount+1;
            xPos(iSample)=-saccadeProfile(xCount)+degrees;
        end
        if xCount==length(saccadeProfile)
            xCount=0;
            xIsSaccade=0;
            xReverse=~xReverse;
        end
    end
end

