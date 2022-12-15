function [e,in]=bareMinimum(e,in)
    in.setstate('start')

    T1=e.targets.T1; % grab T1
    T1.position=T1.randpos; %single out one random position

    % Draw the rect to the screen
    Screen2('FillRect', in,...
        T1.color , T1.squarepos);

    if getsecs>in.checkint(e.getint('T0_reach'))

        in.setstate('stop')
        in.runtrial=0;

    end
end