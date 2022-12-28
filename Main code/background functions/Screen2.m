function Screen2(a,internal,varargin)
if internal.diode_on
    Screen('FillRect', internal.window_main, internal.diode_color, internal.diode_pos);
end
if nargin==2
    Screen(a, internal.window_main);
    Screen(a, internal.window_monitor);
else
    Screen(a, internal.window_main,varargin{:});
    Screen(a, internal.window_monitor,varargin{1},varargin{2}/4,varargin{3:end});
end

%% extra stuff on monitor screen here
Screen('DrawDots', internal.window_monitor, internal.eye.geteye/4, 10 , [1,1,1]);
end