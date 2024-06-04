function GraphicsHandler
% opengl('save','hardware');
addpath('/opt/Trellis/Tools/xippmex');
xippmex;
vblhis=0;
%% set up udp port
graphicsport = udpport("LocalPort",2021, "timeout", 0.01);
%% set up udp callback that listens for "Screen" commands
homepath=genpath('/home/gandhilab/Documents/MATLAB/Gandhi-Psychtoolbox/Main code');
addpath(homepath);
cd '/home/gandhilab/Documents/MATLAB/Gandhi-Psychtoolbox/Main code'

configureCallback(graphicsport,"terminator",@getCommands);

%% initiate a bunch of gr stuff
gr = graphics;
gr.eye=eyeinfo;

%% set up the screens for experiments
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 3);

% Clear the workspace and the screen
sca;
close all;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% priority
Priority(5);

% Get the screen numbers
gr.screens = Screen('Screens');

% Define black and white
black = BlackIndex(1);

% Open an on screen window
% PsychImaging('PrepareConfiguration');
% PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
% PsychImaging('AddTask', 'General', 'FloatingPoint16Bit');

[gr.window_main, gr.windowRect] = PsychImaging('OpenWindow', 1, black);


% Get the size of the on screen window
[gr.screenXpixels, gr.screenYpixels] = Screen('WindowSize', gr.window_main);

%get size of the screen
[gr.width, gr.height]=Screen('DisplaySize',  1);

% set up a monitoring window
monitor_rect=floor(gr.windowRect/2);

PsychImaging('PrepareConfiguration');
% PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
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
try
    Screen('TextSize', gr.window_monitor,30);
    Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 600, 5 , [255,255,255]);
    Screen('Flip', gr.window_monitor);
catch
end

%turn off mouse on monkey screen
HideCursor(gr.window_main)

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
clc
system('clear');
disp('-----Graphics Handler-----')
%% keep function alive
while 1
    pause(0.00001) %allow for callbacks to be checked
    %% evaluate graphics buffer
    if ~isempty(gr.functionsbuffer) && gr.trialstarted && gr.flipped
        flush(graphicsport);
        gr.flipped=0;
        args_uncut={};
        outs={};
        additionalinfo={};
        v = fieldnames(gr.functionsbuffer);
        for ii = 1 : length(v) %unwrap commands
            eval([v{ii} '= gr.functionsbuffer.' v{ii} ';']);
        end
        gr.functionsbuffer=[];

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
                            matches(args{2},'windowPtr') &&...
                            ~matches(args{1},'flip','IgnoreCase',true)

                        Screen(args{1},gr.window_main);
                        Screen(args{1},gr.window_monitor);

                    elseif length(args)>2 && matches(args{2},'windowPtr')

                        Screen(args{1},gr.window_main,args{3:end});

                        if (isstring(args{1}) || ischar(args{1})) && matches(args{1},'DrawTexture','IgnoreCase',true)
                            args{3}=additionalinfo{1};
                            try
                                Screen(args{1},gr.window_monitor,args{3:end});
                            catch
                                disp("Couldn't draw a texture on monitor-screen")
                            end
                        else
                            Screen(args{1},gr.window_monitor,args{3:end});
                        end
                    elseif length(args)>2 && matches(args{2},'monitoronly')
                        try
                            Screen(args{1},gr.window_monitor,args{3:end});
                        catch
                            disp("Couldn't draw something on monitor-screen")
                        end
                    end
                else
                    Screen(args{:});
                end
            end

                %% if output is requested
            % elseif ~isempty(outs)
            %     a1=[];a2=[];a3=[];a4=[];a5=[];a6=[];a7=[];
            %     evalstring=strcat('[',sprintf('%s,',outs{:}),']');
            % 
            %     if length(args)>=2 %this needs to change to better logic
            %         args{2}=gr.window_main;
            %     end
            % 
            %     eval(strcat(evalstring,'=Screen(args{:});'));
            % 
            %     outstr='';
            %     for ii=1:length(outs)
            %         outstr=strcat(outstr,outs{ii},'=',string(eval(outs{ii})),';');
            %     end
            %     writeline(graphicsport,strcat('mh.graphicssent=0;', outstr),'0.0.0.0',2020)
            % end

            %% movie logic
            % if (isstring(args{1}) || ischar(args{1})) && matches(args{1},'PlayMovie','IgnoreCase',true)
            %     gr.movieplaying=1;
            %     disp('movie playing')
            % elseif (isstring(args{1}) || ischar(args{1})) && matches(args{1},'CloseMovie','IgnoreCase',true)
            %     gr.movieplaying=0;
            %     disp('movie closed')
            % end
            % if gr.movieplaying==1
            %     gr.texture=Screen('GetMovieImage', gr.window_main, gr.movie);
            %     gr.monitortexture=Screen('MakeTexture', gr.window_monitor, gr.monitormovieplaceholder);
            %     disp('got texture')
            % end
            clear args 
        end
        clear args args_uncut  outs   additionalinfo

    elseif gr.trialstarted && ~gr.flipped 
        Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]);
        Screen('TextSize', gr.window_monitor,30);
        Screen('DrawText', gr.window_monitor, gr.activestatename, 5, 5 , [255,255,255]);
        Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 600, 5 , [255,255,255]);
        Screen('DrawLines',gr.window_monitor,gr.gridlinesmatrix,1,[.3 .3 .3]);
        Screen('FrameOval',gr.window_monitor,[.3 .3 .3],gr.center_circle,3);
        Screen('FillRect', gr.window_main, gr.diode_color, gr.diode_pos);
        Screen('FillRect', gr.window_monitor, gr.diode_color, gr.diode_pos);
        
        vbl=Screen('Flip',gr.window_main);
        gr.fliptimes=[gr.fliptimes getsecs];
        gr.commandIDs=[gr.commandIDs gr.commid_udp];
        Screen('Flip',gr.window_monitor,[],[],1);
        writeline(graphicsport,'mh.readyforflip=1;','0.0.0.0',2020);
        if vbl-vblhis>0.05
            disp('stuttered')
        end
        vblhis=vbl;

        if ~strcmp(gr.state_history{end},gr.activestatename)
            gr.state_history{end+1}=gr.activestatename;
            gr.diode_color=abs(gr.diode_color-1); 
            disp(join(["changed diode for state: " gr.activestatename]));
        end

        clear allargs
        gr.functionsbuffer=[];
        gr.flipped=1;
        Screen('Close');
    end
    %% this is to show eye when trials are not running
    if ~gr.trialstarted
        % disp('out of trial')
        writeline(graphicsport,'mh.readyforflip=1;','0.0.0.0',2020);
        try
            seteye;
        catch
        end
        Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]);
        Screen('TextSize', gr.window_monitor,30);
        try
            Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 600, 5 , [255,255,255]);
        catch
        end
        
        Screen('DrawLines',gr.window_monitor,gr.gridlinesmatrix,1,[.3 .3 .3]);

        Screen('FillRect', gr.window_main, gr.diode_color, gr.diode_pos);
        Screen('FillRect', gr.window_monitor, gr.diode_color, gr.diode_pos);
        Screen('FrameOval',gr.window_monitor,[.3 .3 .3],gr.center_circle,3);
        Screen('Flip',gr.window_monitor);
        Screen('Flip',gr.window_main);
        gr.functionsbuffer=[];
        Screen('Close');
    end
end
%% callback function that does the graphics handling
    function getCommands(graphicsport,~)
        try
        command=readline(graphicsport);
            if contains(command,'SetEye','IgnoreCase',true)
                seteye;
            elseif contains(command,'execute','IgnoreCase',true)
                rawexecute(command);
            else
                executeScreen(command);
            end
        catch
        end
    end

%% recive and execute Screen calls
    function executeScreen(command)
        args_udp={};
        outs_udp={};
        additionalinfo_udp={};
        commandID_udp={};
        gr.lastarg=1;
        eval(command);

        gr.functionsbuffer(end+1).args_uncut=args_udp;
        gr.functionsbuffer(end+1).outs=outs_udp;
        gr.functionsbuffer(end+1).additionalinfo=additionalinfo_udp;
        gr.commid_udp=commandID_udp;
        flush(graphicsport);
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
        gr.center_circle=[deg2pix([0 0])-10 deg2pix([0 0])+10];
    end
%% execut raw stream
    function rawexecute(command)
        gr;
        eval(erase(command,'execute'))
    end
%%data save function
    function dumpdata(fname)
        gr;
        temptr=[];
        trname=[];
        disp('trying to dump data')
        fname=strtrim(fname);
        temptr=load(fname);
        trname=fields(temptr);
        temptr.(trname{:}).data.graphics_fliptimes.fliptimes=gr.fliptimes;
        temptr.(trname{:}).data.graphics_fliptimes.commandIDs = gr.commandIDs;
        temptr.(trname{:}).data.DiodeFlipStates={gr.state_history{2:end}};
        gr.commandIDs=[];gr.fliptimes=[];gr.state_history={'null'};
        save(fname,'-struct','temptr');
        disp(join(['saved ',trname{:}]))
    end
end


