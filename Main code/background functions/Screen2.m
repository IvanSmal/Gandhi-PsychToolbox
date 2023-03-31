function out=Screen2(a,mh,varargin)
if nargin>1
    checkint2=inputname(2);
    if matches(checkint2,'mh')
        if mh.diode_on
            Screen('FillRect', mh.window_main, mh.diode_color, mh.diode_pos);
        end
        try
            Screen(a, mh.window_main,varargin{:});
        catch
            out=Screen(a, mh.window_main,varargin{:});
        end
        try
            if matches(a,'DrawTexture','IgnoreCase',1)
                if nargin==3
                    Screen(a, mh.window_monitor,varargin{1},mh.windowRect,mh.monitor_rect)
                else
                    Screen(a, mh.window_monitor,varargin{1},varargin{2},varargin{3}/4,varargin{4:end});
                end
            else
                try
                    Screen(a, mh.window_monitor,varargin{1},varargin{2}/4,varargin{3:end});
                catch
                    Screen(a, mh.window_monitor,varargin{1},varargin{2}/4)
                    disp('here')
                end
            end
        catch
            Screen('TextSize', mh.window_monitor,9);
            Screen('DrawText', mh.window_monitor, 'couldn''t draw something in monitor window', 5, 12 , [1,1,1]);
        end
        %% extra stuff on monitor screen here
        Screen('DrawDots', mh.window_monitor, mh.eye.geteye/4, 3 , [1,1,1]);
        Screen('TextSize', mh.window_monitor,9);
        Screen('DrawText', mh.window_monitor, mh.activestatename, 5, 5 , [1,1,1]);
    else
        try
            out=Screen(a, mh,varargin{:});
        catch
            Screen(a, mh,varargin{:});
        end
    end
else
    Screen(a);
end
end