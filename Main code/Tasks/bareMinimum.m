function [e,internal]=bareMinimum(e,internal)
    
    T1=e.targets.T1; % grab T1
    T1.position=T1.randpos; %single out one random position

    % Draw the rect to the screen
    Screen2('FillRect', internal,...
        T1.color , T1.squarepos);

    if cputime>...
            (e.getint('T0_reach')+internal.tstarttime)
        internal.runtrial=0;
    end
end