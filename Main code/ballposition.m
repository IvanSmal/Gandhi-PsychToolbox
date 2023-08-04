function [posout,dirout]=ballposition(mh,curpos,curdir,paddlepos,speed,mode)
%% PHYSICS
if matches(mode,'up_down')
    posout=curpos+[0 speed*tim*curdir 0 speed*tim*curdir];
    if (any(ismember(posout([2 4]),paddlepos(2):paddlepos(4))) &&...
            any(ismember(posout([1 3]),paddlepos(1):paddlepos(3)))) ||...
            any(ismember(posout([2 4]),0))
        dirout=-curdir;
    else
        dirout=curdir;
    end
end

end