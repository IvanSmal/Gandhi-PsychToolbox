function w=diode(w,e,statecount)
if rem(statecount,2)
    d_col=[1;1;1];
else
    d_col=[0;0;0];
end
    Screen('FillRect', w.window_main, d_col, e.diodepos);
    Screen('Flip', w.window_main);
end