function out=Screen2(a,mh,varargin)

if nargin>1
    checkint2=inputname(2);
    if matches(checkint2,'mh')
        if ~contains(a,'movie','IgnoreCase',1)
            if mh.diode_on
                Screen('FillRect', mh.window_main, mh.diode_color, mh.diode_pos);
                Screen('FillRect', mh.window_monitor, mh.diode_color, mh.diode_pos);
            end
            %this try-catch will do stuff for main window. Basically
            %untouched pass from Screen() to Screen2()
            try
                Screen(a, mh.window_main,varargin{:});
                Screen(a, mh.window_monitor,varargin{:});
            catch
                out=Screen(a, mh.window_main,varargin{:});
                out=Screen(a, mh.window_monitor,varargin{:});
            end
        else
            try
                out=Screen(a, mh.window_main,varargin{:});
                disp(here)
            catch
                Screen(a, mh.window_main,varargin{:});
            end
            %% tell user that the movie is on
            Screen('TextSize', mh.window_monitor,20);
            Screen('DrawText', mh.window_monitor, 'MOVIE PLAYING', mh.xCenter, mh.yCenter , [255,255,255]);
        end
        %% extra stuff on monitor
        eyepos=mh.eye.geteye;
        Screen('DrawDots', mh.window_monitor, eyepos, 10 , [255,255,255]);
        Screen('TextSize', mh.window_monitor,20);
        Screen('DrawText', mh.window_monitor, mh.activestatename, 5, 5 , [255,255,255]);
        Screen('DrawText', mh.window_monitor, num2str(eyepos), mh.xCenter, 5 , [255,255,255]);
    else
        try
            varargout=Screen(a, mh,varargin{:});
        catch
            Screen(a, mh,varargin{:});
        end
    end
else
    Screen(a);
end
