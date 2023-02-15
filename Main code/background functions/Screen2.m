function Screen2(a,in,varargin)
if in.diode_on
        Screen('FillRect', in.window_main, in.diode_color, in.diode_pos);
end

if nargin==2
    Screen(a, in.window_main);
    Screen(a, in.window_monitor);
else
    Screen(a, in.window_main,varargin{:});
    try
    scaScreen(a, in.window_monitor,varargin{1},varargin{2}/4,varargin{3:end});
    end
end

%% extra stuff on monitor screen here
Screen('DrawDots', in.window_monitor, in.eye.geteye/4, 10 , [1,1,1]);
Screen('TextSize', in.window_monitor,9);
Screen('DrawText', in.window_monitor, in.activestatename, 5, 5 , [1,1,1]);
end