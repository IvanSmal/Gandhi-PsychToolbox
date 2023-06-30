function GraphicsHandler
%% set up udp port
graphicsport = udpport("LocalPort",2021);
%% set up udp callback that listens for "Screen" commands
homepath=genpath('/home/gandhilab/Documents/MATLAB/Gandhi-Psychtoolbox/Main code');
addpath(homepath);
cd '/home/gandhilab/Documents/MATLAB/Gandhi-Psychtoolbox/Main code'

gr=graphics;
configureCallback(graphicsport,"terminator",@getCommands);

gr.eye=eyeinfo;
gr.flipped=0;
gr.activestatename='null';

%% set up the screens for experiments
Screen('Preference', 'SkipSyncTests', 0);
% Priority(2);

% % set experimental environment
% setenv('PSYCH_EXPERIMENTAL_NETWMTS', '1');

% Clear the workspace and the screen
sca;
close all;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% Get the screen numbers
gr.screens = Screen('Screens');

% Define black and white
black = BlackIndex(1);

% Open an on screen window

PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
PsychImaging('AddTask', 'General', 'FloatingPoint16Bit');
% PsychImaging('AddTask', 'General',...
%     'MirrorDisplayTo2ndOutputHead',...
%     0 , monitor_rect);%, specialFlags=0][, useOverlay=0]);

[gr.window_main, gr.windowRect] = PsychImaging('OpenWindow', 1, black);


% Get the size of the on screen window
[gr.screenXpixels, gr.screenYpixels] = Screen('WindowSize', gr.window_main);

%get size of the screen
[gr.width, gr.height]=Screen('DisplaySize',  1);

% set up a monitoring window
monitor_rect=floor(gr.windowRect/2);

PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
PsychImaging('AddTask', 'General', 'UsePanelFitter', [gr.screenXpixels, gr.screenYpixels], 'Full');
% PsychImaging('AddTask', 'General', 'FloatingPoint16Bit')
[gr.window_monitor, gr.monitor_rect]=PsychImaging('OpenWindow', 0, black,monitor_rect,[],[],[],[],[],kPsychGUIWindow);

% Get the centre coordinate of the window
[gr.xCenter, gr.yCenter] = RectCenter(gr.windowRect);


% iode stuff
gr.diode_pos=[0,gr.screenYpixels-50,50,gr.screenYpixels];

% for some reason draw a circle for a frame idk why i need to do this

Screen('FillOval', gr.window_main, [1 1 1], [0 0 10 10]);
Screen('Flip', gr.window_main);

Screen('FillOval', gr.window_monitor, [1 1 1], [0 0 10 10]);
Screen('Flip', gr.window_monitor);

% set up movie placeholder image for monitor
gr.monitormovieplaceholder=imread("assets/MoviePlaceholder.jpg");

% send ready signal to mh
writeline(graphicsport,'isGraphicsReady=1;','0.0.0.0',2020);


%% keep function alive
while 1
    pause(0.0001) %allow for callbacks to be checked
end
%% callback function that does the graphics handling
    function getCommands(graphicsport,~)
        graphicsport.UserData.in=readline(graphicsport);
        if contains(graphicsport.UserData.in,'SetEye','IgnoreCase',true)
            seteye;
        elseif contains(graphicsport.UserData.in,'execute','IgnoreCase',true)
            rawexecute(graphicsport);
        else
            executeScreen(graphicsport);
        end
    end

%% recive and execute Screen calls
    function executeScreen(graphicsport)
        
        setmet=1;
        args={};
        outs={};
        additionalinfo={};
        eval(graphicsport.UserData.in);
        if length(args)>2 &&...
                (isstring(args{end-1}) || ischar(args{end-1})) &&...
                matches(args{end-1},'set','IgnoreCase',true)

            if length(args)>=2 %this needs to change to better logic
                args{2}=gr.window_main;
                if contains(args{end},'monitor')
                    args{2}=gr.window_monitor;
                end
            end

            evalstring=strcat(args{end},'=Screen(args{1:end-2});');
            eval(evalstring);
            setmet=0;
            gr.flipped=0;
        end

        if isempty(outs) && setmet
            if length(args) >= 2 && (isstring(args{2}) || ischar(args{2}))
                if length(args)==2 &&...
                        matches(args{2},'mh') &&...
                        ~matches(args{1},'flip','IgnoreCase',true)

                    Screen(args{1},gr.window_main);
                    Screen(args{1},gr.window_monitor);
                    gr.flipped=0;

                elseif length(args)>2 && matches(args{2},'mh')

                    Screen(args{1},gr.window_main,args{3:end});

                    if (isstring(args{1}) || ischar(args{1})) && matches(args{1},'DrawTexture','IgnoreCase',true)
                        args{3}=additionalinfo{1};
                        try
                            Screen(args{1},gr.window_monitor,args{3:end});
                        end
                    end

                    gr.flipped=0;
                end
            else
                Screen(args{:});
                gr.flipped=0;
            end

        elseif ~isempty(outs) && setmet
            a1=[];a2=[];a3=[];a4=[];a5=[];a6=[];a7=[];
            evalstring=strcat('[',sprintf('%s,',outs{:}),']');

            if length(args)>=2 %this needs to change to better logic
                args{2}=gr.window_main;
            end

            eval(strcat(evalstring,'=Screen(args{:});'));

            outstr='';
            for i=1:length(outs)
                outstr=strcat(outstr,outs{i},'=',string(eval(outs{i})),';');
            end
            writeline(graphicsport,strcat('mh.graphicssent=0;', outstr),'0.0.0.0',2020)
        end

        %% movie logic
        if (isstring(args{1}) || ischar(args{1})) && matches(args{1},'PlayMovie','IgnoreCase',true)
            gr.movieplaying=1;
            disp('movie playing')
        elseif (isstring(args{1}) || ischar(args{1})) && matches(args{1},'CloseMovie','IgnoreCase',true)
            gr.movieplaying=0;
            disp('movie closed')
        end

        if gr.movieplaying==1
            gr.texture=Screen('GetMovieImage', gr.window_main, gr.movie);
            gr.monitortexture=Screen('MakeTexture', gr.window_monitor, gr.monitormovieplaceholder);
            disp('got texture')
            gr.flipped=0;
        end

        %% extra stuff on monitor
        Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]);
        Screen('TextSize', gr.window_monitor,80);
        Screen('DrawText', gr.window_monitor, gr.activestatename, 5, 5 , [255,255,255]);
        Screen('DrawText', gr.window_monitor, num2str(gr.eye.geteye), gr.xCenter, 5 , [255,255,255]);

        if ~isempty(args) && setmet
            if matches(args{1},'Flip','IgnoreCase',true) %&& gr.flipped==0
                Screen('FillRect', gr.window_main, gr.diode_color, gr.diode_pos);
                Screen('Flip',gr.window_main,[],1);
                Screen('Flip',gr.window_monitor);
                gr.flipped=1;
                flush(graphicsport)
            end
        end

    end
%% set eye calibration
    function seteye
        gr.eye=eyeinfo;
    end
%% execut raw stream
    function rawexecute(graphicsport)
        gr;
        eval(erase(graphicsport.UserData.in,'execute'))
    end
end


