function GraphicsHandler
debug=0;
if ~debug
    rmpath('/home/gandhilab/Documents/MATLAB/Gandhi-Psychtoolbox/Main code/DEBUG') % remove DEBUG code override
end
addpath('/opt/Trellis/Tools/xippmex');
xippmex;
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
[gr.window_monitor, gr.monitor_rect]=PsychImaging('OpenWindow', 0, black,monitor_rect,[],[],[],[],[],kPsychGUIWindow);

% Get the centre coordinate of the window
[gr.xCenter, gr.yCenter] = RectCenter(gr.windowRect);


% diode stuff
gr.diode_pos=[0,gr.screenYpixels-20,20,gr.screenYpixels];

% for some reason draw a circle for a frame idk why i need to do this, but
% otherwise it will not display circles
Screen('FillOval', gr.window_main, [1 1 1], [0 0 10 10]);
Screen('Flip', gr.window_main);

Screen('FillOval', gr.window_monitor, [1 1 1], [0 0 10 10]);
Screen('Flip', gr.window_monitor);

% set up movie placeholder image for monitor
gr.monitormovieplaceholder=imread("assets/MoviePlaceholder.jpg");

%set up grid params
toconvert(:,1)=-40:10:40;
toconvert(:,2)=-40:10:40;
pixelsforlines=deg2pix(toconvert,'cart');
xlines=reshape(repmat(pixelsforlines(:,1),2)',1,[]);
fully=reshape(repmat([0 1080], length(xlines)/2,1)',1,[]);
ylines = reshape(repmat(pixelsforlines(:,2),2)',1,[]);
fullx=reshape(repmat([0 3000], length(ylines)/2,1)',1,[]);
gr.gridlinesmatrix=[xlines fullx;fully ylines];


% send ready signal to mh
writeline(graphicsport,'isGraphicsReady=1;','0.0.0.0',2020);


%% keep function alive
while 1
    pause(0.0001) %allow for callbacks to be checked
    %% evaluate graphics buffer
    if ~isempty(gr.functionsbuffer) && gr.trialstarted
        gr.flipped=0;
        args_uncut={};
        outs={};
        additionalinfo={};

        v = fieldnames(gr.functionsbuffer);
        for ii = 1 : length(v) %unwrap commands
            eval([v{ii} '= gr.functionsbuffer.' v{ii} ';']);
        end

        commandcount=1;
        lastargcount=1;
        for iii = 1:length(args_uncut)
            if strcmp(args_uncut{iii},'endcommand')
                % args_uncut(iii)=[];
                allargs{commandcount}=args_uncut(lastargcount:iii-1);
                commandcount=commandcount+1;
                lastargcount=iii+1;
            end
        end

        for i=1:length(allargs)
            args=allargs{i};
            %% check if user wants to set a graphics parameter
            if length(args)>2 &&...
                    (isstring(args{end-1}) || ischar(args{end-1})) &&...
                    matches(args{end-1},'set','IgnoreCase',true)           % this is to check if the user wants to set a parameter in the graphics handler

                % user MUST be setting something to a window
                args{2}=gr.window_main;
                if contains(args{end},'monitor')
                    args{2}=gr.window_monitor;
                end

                evalstring=strcat(args{end},'=Screen(args{1:end-2});');
                eval(evalstring);
            end
            if isempty(outs)
                if length(args) >= 2 && (isstring(args{2}) || ischar(args{2}))
                    if length(args)==2 &&...
                            matches(args{2},'mh') &&...
                            ~matches(args{1},'flip','IgnoreCase',true)

                        Screen(args{1},gr.window_main);
                        Screen(args{1},gr.window_monitor);

                    elseif length(args)>2 && matches(args{2},'mh')

                        Screen(args{1},gr.window_main,args{3:end});

                        if (isstring(args{1}) || ischar(args{1})) && matches(args{1},'DrawTexture','IgnoreCase',true)
                            args{3}=additionalinfo{1};
                            try
                                Screen(args{1},gr.window_monitor,args{3:end});
                            end
                        else
                            Screen(args{1},gr.window_monitor,args{3:end});
                        end
                    elseif length(args)>2 && matches(args{2},'monitoronly')
                        try
                            Screen(args{1},gr.window_monitor,args{3:end});
                        end
                    end
                else
                    Screen(args{:});
                end
                %% if output is requested
            elseif ~isempty(outs)
                a1=[];a2=[];a3=[];a4=[];a5=[];a6=[];a7=[];
                evalstring=strcat('[',sprintf('%s,',outs{:}),']');

                if length(args)>=2 %this needs to change to better logic
                    args{2}=gr.window_main;
                end

                eval(strcat(evalstring,'=Screen(args{:});'));

                outstr='';
                for ii=1:length(outs)
                    outstr=strcat(outstr,outs{ii},'=',string(eval(outs{ii})),';');
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
            end
        end
        Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]);
        Screen('TextSize', gr.window_monitor,30);
        Screen('DrawText', gr.window_monitor, gr.activestatename, 5, 5 , [255,255,255]);
        Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 600, 5 , [255,255,255]);
        Screen('DrawLines',gr.window_monitor,gr.gridlinesmatrix,1,[.3 .3 .3]);

        Screen('FillRect', gr.window_main, gr.diode_color, gr.diode_pos);
    elseif isempty(gr.functionsbuffer) && gr.trialstarted && ~gr.flipped
        Screen('Flip',gr.window_monitor);
        Screen('Flip',gr.window_main);
        clear allargs
        gr.flipped=1;
    end
    %% this is to show eye when trials are not running
    if ~gr.trialstarted
        Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]);
        Screen('TextSize', gr.window_monitor,30);
        % Screen('DrawText', gr.window_monitor, gr.activestatename, 5, 5 , [255,255,255]);
        try
        Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 600, 5 , [255,255,255]);
        end
        Screen('DrawLines',gr.window_monitor,gr.gridlinesmatrix,1,[.3 .3 .3]);

        Screen('FillRect', gr.window_main, gr.diode_color, gr.diode_pos);
        Screen('Flip',gr.window_monitor);
        Screen('Flip',gr.window_main);
    end
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
        args_udp={};
        outs_udp={};
        additionalinfo_udp={};
        gr.lastarg=1;
        eval(graphicsport.UserData.in);

        gr.functionsbuffer(end+1).args_uncut=args_udp;
        gr.functionsbuffer(end+1).outs=outs_udp;
        gr.functionsbuffer(end+1).additionalinfo=additionalinfo_udp;
    end
%% set eye calibration
    function seteye
        gr.eye=eyeinfo;
        toconvert(:,1)=-40:10:40;
        toconvert(:,2)=-40:10:40;
        pixelsforlines=deg2pix(toconvert,'cart');
        xlines=reshape(repmat(pixelsforlines(:,1),2)',1,[]);
        fully=reshape(repmat([0 1080], length(xlines)/2,1)',1,[]);
        ylines = reshape(repmat(pixelsforlines(:,2),2)',1,[]);
        fullx=reshape(repmat([0 3000], length(ylines)/2,1)',1,[]);
        gr.gridlinesmatrix=[xlines fullx;fully ylines];

    end
%% execut raw stream
    function rawexecute(graphicsport)
        gr;
        eval(erase(graphicsport.UserData.in,'execute'))
    end
end


