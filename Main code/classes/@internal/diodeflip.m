function diodeflip(mh)
if ~mh.diode_on
    mh.diode_color=[1;1;1];
    mh.diode_on = 1;
else
    mh.diode_color=[0;0;0];
    mh.diode_on = 0;
end
mh.evalgraphics(['gr.diode_color=' mat2str(mh.diode_color) '; disp("changed diode color");'])
end