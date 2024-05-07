function diodeflip(mh)
mh.evalgraphics('gr.diode_color=abs(gr.diode_color-1); disp(["changed diode for state: " gr.activestatename]);')
end