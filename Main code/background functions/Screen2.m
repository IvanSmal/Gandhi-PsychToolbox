function out=Screen2(a,in,varargin)
checkint2=inputname(2);
if matches(checkint2,'mh')
    if in.diode_on
        Screen('FillRect', in.window_main, in.diode_color, in.diode_pos);
    end
    try
        Screen(a, in.window_main,varargin{:});
    catch
        out=Screen(a, in.window_main,varargin{:});
    end
    try
        if matches(a,'DrawTexture','IgnoreCase',1)
            if nargin==3
                Screen(a, in.window_monitor,varargin{1},in.windowRect,in.monitor_rect)
            else
                Screen(a, in.window_monitor,varargin{1},varargin{2},varargin{3}/4,varargin{4:end});
            end
        else
            Screen(a, in.window_monitor,varargin{1},varargin{2}/4,varargin{3:end});
        end
    end
    %% extra stuff on monitor screen here
    Screen('DrawDots', in.window_monitor, in.eye.geteye/4, 10 , [1,1,1]);
    Screen('TextSize', in.window_monitor,9);
    Screen('DrawText', in.window_monitor, in.activestatename, 5, 5 , [1,1,1]);
else
    try
        out=Screen(a, in,varargin{:});
    catch
        Screen(a, in,varargin{:});
    end
end
end