function internal=diode(internal,e,statecount)
if rem(statecount,2)
    d_col=[1;1;1];
else
    d_col=[0;0;0];
end
    Screen2('FillRect', internal, d_col, e.diodepos);
    Screen2('Flip', internal);
end