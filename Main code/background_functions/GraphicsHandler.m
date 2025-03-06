function GraphicsHandler
% opengl('save','hardware');
pathhere=pwd;
pathhere=pathhere(1:end-21);
filepaths_path=[pathhere '/inis/FilePaths.ini'];
filepaths_ini=IniConfig();
filepaths_ini.ReadFile(filepaths_path);
addpath(genpath(filepaths_ini.GetValues('paths','home')));
addpath(filepaths_ini.GetValues('paths','xippmex'));
xippmex;
vblhis=0;
vbl=0;
warning ('off','all');
%% set up udp port
graphicsport = udpport("LocalPort",2021, "timeout", 0.02);

%% initiate a bunch of gr stuff
gr.screenparams= IniConfig();
gr.screenparams.ReadFile(filepaths_ini.GetValues('paths','ini_screen'));
bgcolor=gr.screenparams.GetValues('screen info','background');
gr = graphics;
gr.eye=eyeinfo;

%% set up the screens for experiments
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 3);

%set the resolution
%Screen('Resolution',1,1920,1080,120)

% Clear the workspace and the screen
sca;
close all;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% Screen('Resolution',1,1920,1080,120); %set resolutions

% priority
Priority(90);

% Get the screen numbers
gr.screens = Screen('Screens');

% Define black and white
black = BlackIndex(1);

% Open an on screen window
PsychImaging('PrepareConfiguration');
% PsychImaging('AddTask', 'General', 'UseFineGrainedTiming');
PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
% PsychImaging('AddTask', 'General', 'FloatingPoint16Bit');

[gr.window_main, gr.windowRect] = PsychImaging('OpenWindow', 1, bgcolor);

% Get the size of the on screen window
[gr.screenXpixels, gr.screenYpixels] = Screen('WindowSize', gr.window_main);

%get size of the screen
[gr.width, gr.height]=Screen('DisplaySize',  1);

% set up a monitoring window
monitor_rect=floor(gr.windowRect/2);

PsychImaging('PrepareConfiguration');
% PsychImaging('AddTask', 'General', 'UseVirtualFramebuffer');
PsychImaging('AddTask', 'General', 'UsePanelFitter', [gr.screenXpixels, gr.screenYpixels], 'Full');

[gr.window_monitor, gr.monitor_rect]=PsychImaging('OpenWindow', 0, bgcolor,monitor_rect,[],[],[],[],[],kPsychGUIWindow);

gr.original_monitor_params=Screen('PanelFitter', gr.window_monitor);
gr.winparams=gr.original_monitor_params;
gr.newsize=Screen('GlobalRect',gr.window_monitor);
gr.newsize_true(1)=gr.newsize(3)-gr.newsize(1);
gr.newsize_true(2)=gr.newsize(4)-gr.newsize(2);

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

% create the info window
createInfoWindow(gr)

% other
fliptime=0.033;

try
    Screen('TextSize', gr.window_monitor,gr.fontsize);
    Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 600, 5 , [255,255,255]);
    Screen('Flip', gr.window_monitor);
catch
end

%turn off mouse on monkey screen
HideCursor(gr.window_main)

% set up movie placeholder image for monitor
gr.monitormovieplaceholder=imread("assets/MoviePlaceholder.jpg");

%set up grid params
gr.toconvert(:,1)=-40:10:40;
gr.toconvert(:,2)=-40:10:40;
gr=makegridlines(gr);


% send ready signal to mh
clc
system('clear');
warning('off')
disp('-----Graphics Handler-----')

seteye
% monitorflipped=0
%% keep function alive
while 1
    try %error handler
        % pause(0.00001) %allow for callbacks to be checked
        getCommands(graphicsport)
        %% evaluate graphics buffer
        runonce=0;
        flipcount=0;
        vbl=0;
        while gr.trialstarted
            getCommands(graphicsport);

            if isempty(gr.functionsbuffer)
                continue;
            end

            % First time setup
            if runonce == 0
                setgrid(gr);
                Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10, [255,255,255]);
                runonce = 1;
            end

            % State change detection
            if ~strcmp(gr.state_history{end}, gr.activestatename)
                gr.state_history{end+1} = gr.activestatename;
                gr.diode_color = abs(gr.diode_color-1);
                disp(join(["changed diode for state: " gr.activestatename]));
            end

            % Timing data collection
            gr.fliptimes = [gr.fliptimes getsecs];
            gr.commandIDs = [gr.commandIDs gr.commid_udp];

            % Command parsing - only execute once
            if ~exist('allargs','var')
                try
                    [additionalinfo, allargs, outs] = parsecommands(gr);
                catch
                    continue;
                end
            else
                % Drawing and flipping
                Screen('FillRect', gr.window_main, gr.diode_color, gr.diode_pos);
                DrawScreen(gr, additionalinfo, allargs, outs);

                clear additionalinfo allargs outs

                fliptime = vbl - vblhis;
                vblhis = vbl;

                vbl = getsecs;
                Screen('Flip', gr.window_main, [], [], 1);
                flipcount = flipcount + 1;

                % Update monitor screen periodically
                if flipcount > 3
                    Screen('FillRect', gr.window_monitor, gr.diode_color, gr.diode_pos);
                    Screen('Flip', gr.window_monitor, [], [], 2);
                    updategui(gr);
                    runonce = 0;
                    flipcount = 0;
                end

                flipped = 1;
            end
        end
    end
    %% this is to show eye when trials are not running
    while ~gr.trialstarted
        % send ready signal to mh
        writeline(graphicsport,'isGraphicsReady=1;','0.0.0.0',2020);

        getCommands(graphicsport)
        writeline(graphicsport,'mh.readyforflip=1;','0.0.0.0',2020);
        gr=makegridlines(gr);
        try
            seteye;
        catch
        end
        setgrid(gr);
        Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]);

        gr.newsize=Screen('GlobalRect',gr.window_monitor);
        gr.newsize_true(1)=gr.newsize(3)-gr.newsize(1);
        gr.newsize_true(2)=gr.newsize(4)-gr.newsize(2);
        gr.winparams=Screen('PanelFitter', gr.window_monitor);
        gr.winparams(1:4)=ceil(gr.winparams(1:4)*gr.scalefactor);
        gr.scalefactor=1;
        gr.winparams([1,3])=ceil(gr.winparams([1,3])+gr.left_right);
        gr.left_right=0;
        gr.winparams([2,4])=ceil(gr.winparams([2,4])+gr.up_down);
        gr.up_down=0;
        Screen('PanelFitter', gr.window_monitor, gr.winparams);

        Screen('Flip',gr.window_monitor);
        Screen('Flip',gr.window_main);
        updategui(gr);

        gr.functionsbuffer=[];
        Screen('Close');
    end
catch e
    disp(e.message)
end
end
%% callback function that does the graphics handling
function getCommands(graphicsport)
try
    % Non-blocking read of available data
    bytesAvailable = graphicsport.NumBytesAvailable;
    if bytesAvailable > 0
        data = read(graphicsport, bytesAvailable, 'char');

        if ~isempty(data)
            command = char(data);

            if contains(command,'SetEye','IgnoreCase',true)
                seteye;
            elseif contains(command,'execute','IgnoreCase',true)
                rawexecute(command);
            else
                executeScreen(command);
            end
        end
    end
catch
    % Silent error handling
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
try
    gr.eye=eyeinfo;
    toconvert(:,1)=-40:10:40;
    toconvert(:,2)=-40:10:40;
    pixelsforlines=deg2pix(toconvert,'cart');
    xlines=reshape(repmat(pixelsforlines(:,1),2)',1,[]);
    fully=reshape(repmat([0 1080], length(xlines)/2,1)',1,[]);
    ylines = reshape(repmat(pixelsforlines(:,2),2)',1,[]);
    fullx=reshape(repmat([0 3000], length(ylines)/2,1)',1,[]);
    gr.gridlinesmatrix=[xlines fullx;fully ylines];
    truezero=deg2pix([0 0]);
    degadds=deg2pix([10 10;20 20; 30 30; 40 40; 50 50],'cart')-truezero;
    degadds(:,2)=[];

    gr.center_circle=[truezero-10 truezero+10;...
        truezero-degadds truezero+degadds]';
catch e
    disp(e.message)
end
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
%%parse the commands without drawing'
function [additionalinfo, allargs, outs] = parsecommands(gr)
flush(graphicsport);
gr.flipped = 0;

% Direct access to buffer data
args_uncut = gr.functionsbuffer.args_uncut;
outs = gr.functionsbuffer.outs;
additionalinfo = gr.functionsbuffer.additionalinfo;

gr.functionsbuffer = [];

% Pre-allocate allargs for better performance
maxCommands = length(args_uncut);
allargs = cell(1, maxCommands);

commandcount = 1;
lastargcount = 1;

for iii = 1:length(args_uncut)
    if strcmp(args_uncut{iii}, 'endcommand')
        allargs{commandcount} = args_uncut(lastargcount:iii-1);
        commandcount = commandcount + 1;
        lastargcount = iii + 1;
    end
end

% Trim the allargs array to actual size
allargs = allargs(1:commandcount-1);
end

function DrawScreen(gr, additionalinfo, allargs, outs)
% Pre-check windows
mainWindow = gr.window_main;
monitorWindow = gr.window_monitor;

for i = 1:length(allargs)
    args = allargs{i};

    % Parameter setting operations
    if length(args) > 2 && (isstring(args{end-1}) || ischar(args{end-1})) && strcmpi(args{end-1}, 'set')
        args{2} = mainWindow;
        if contains(args{end}, 'monitor')
            args{2} = monitorWindow;
        end

        % Faster than eval for simple assignment
        if strcmpi(args{end}, 'texture')
            gr.texture = Screen(args{1:end-2});
        elseif strcmpi(args{end}, 'monitortexture')
            gr.monitortexture = Screen(args{1:end-2});
        else
            % Fall back to eval only when necessary
            evalstring = [args{end}, '=Screen(args{1:end-2});'];
            eval(evalstring);
        end
        continue;
    end

    % Screen operations with no output
    if isempty(outs)
        if length(args) >= 2 && (isstring(args{2}) || ischar(args{2}))
            if length(args) == 2 && strcmpi(args{2}, 'windowPtr') && ~strcmpi(args{1}, 'flip')
                Screen(args{1}, mainWindow);
                Screen(args{1}, monitorWindow);
            elseif length(args) > 2 && strcmpi(args{2}, 'windowPtr')
                Screen(args{1}, mainWindow, args{3:end});

                if (isstring(args{1}) || ischar(args{1})) && strcmpi(args{1}, 'DrawTexture')
                    % Special handling for textures on monitor
                    try
                        monitorArgs = args;
                        monitorArgs{2} = monitorWindow;
                        monitorArgs{3} = additionalinfo{1};
                        Screen(monitorArgs{:});
                    catch
                        % No error message in high-frequency loop for performance
                    end
                else
                    monitorArgs = args;
                    monitorArgs{2} = monitorWindow;
                    Screen(monitorArgs{:});
                end
            elseif length(args) > 2 && strcmpi(args{2}, 'monitoronly')
                try
                    monitorArgs = args;
                    monitorArgs{2} = monitorWindow;
                    Screen(monitorArgs{1}, monitorWindow, monitorArgs{3:end});
                catch
                    % No error message in high-frequency loop
                end
            end
        else
            Screen(args{:});
        end
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

gr.functionsbuffer = [];
Screen('DrawingFinished', mainWindow);
end
%%make grid lines function
function gr = makegridlines(gr)
    % Pre-allocate arrays
    if ~isfield(gr, 'gridArraysInitialized') || ~gr.gridArraysInitialized
        gr.pixelsforlines = zeros(size(gr.toconvert));
        gr.xlines = zeros(1, length(gr.toconvert(:,1))*2);
        gr.ylines = zeros(1, length(gr.toconvert(:,2))*2);
        gr.gridArraysInitialized = true;
    end
    
    % Vectorized coordinate conversion
    gr.pixelsforlines = deg2pix(gr.toconvert, 'cart');
    
    % Create grid lines more efficiently
    [xgrid, ~] = meshgrid(gr.pixelsforlines(:,1), [0 1080]);
    gr.xlines = xgrid(:)';
    
    [xgrid, ygrid] = meshgrid([0 3000], gr.pixelsforlines(:,2));
    gr.ylines = ygrid(:)';
    
    % Combine into matrix
    gr.gridlinesmatrix = [gr.xlines, xgrid(:)'; ygrid(:)', gr.ylines];
    
    % Create circle more efficiently
    truezero = deg2pix([0 0]);
    circdegrees = (1:gr.circleadder:90)-1;
    circpoints = [cosd(circdegrees)' sind(circdegrees)'] .* repmat(10:10:50, length(circdegrees), 1);
    degadds = deg2pix(circpoints, 'cart') - truezero;
    
    gr.center_circle = [truezero-10 truezero+10; truezero-degadds truezero+degadds]';
end
%%set grid
function gr=setgrid(gr)
Screen('TextSize', gr.window_monitor,gr.fontsize);
try
    Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 960, 5 , [255,255,255]);

    for i=1:length(gr.toconvert(:,1))
        Screen('DrawText', gr.window_monitor, num2str(gr.toconvert(i,1)), gr.pixelsforlines(i,1),...
            gr.pixelsforlines(ceil(length(gr.toconvert(:,1))/2),2), [.5,.5,.5]);
        Screen('DrawText', gr.window_monitor, num2str(gr.toconvert(i,2)),...
            gr.pixelsforlines(ceil(length(gr.toconvert(:,1))/2),1), gr.pixelsforlines(i,2),  [.5,.5,.5]);
    end
catch
end


Screen('DrawLines',gr.window_monitor,gr.gridlinesmatrix,1,[.3 .3 .3]);
Screen('FrameOval',gr.window_monitor,[0.2 0.2 0.2]',gr.center_circle,3);
end

function createInfoWindow(gr)

% Create UIFigure and hide until all components are created
gr.UIFigure = uifigure('Visible', 'off');
gr.UIFigure.Position = [100 100 441 285];
gr.UIFigure.Name = 'Graphics Info';

% Create xpositionEditFieldLabel
gr.xpositionEditFieldLabel = uilabel(gr.UIFigure);
gr.xpositionEditFieldLabel.HorizontalAlignment = 'right';
gr.xpositionEditFieldLabel.Position = [59 220 56 22];
gr.xpositionEditFieldLabel.Text = 'x position';

% Create xpositionEditField
gr.xpositionEditField = uieditfield(gr.UIFigure, 'text');
gr.xpositionEditField.HorizontalAlignment = 'center';
gr.xpositionEditField.Position = [51 199 72 22];
gr.xpositionEditField.Value = '0';

% Create ypositionEditFieldLabel
gr.ypositionEditFieldLabel = uilabel(gr.UIFigure);
gr.ypositionEditFieldLabel.HorizontalAlignment = 'right';
gr.ypositionEditFieldLabel.Position = [149 220 56 22];
gr.ypositionEditFieldLabel.Text = 'y position';

% Create ypositionEditField
gr.ypositionEditField = uieditfield(gr.UIFigure, 'text');
gr.ypositionEditField.HorizontalAlignment = 'center';
gr.ypositionEditField.Position = [138 199 78 22];
gr.ypositionEditField.Value = '0';

% Create StateEditFieldLabel
gr.StateEditFieldLabel = uilabel(gr.UIFigure);
gr.StateEditFieldLabel.HorizontalAlignment = 'right';
gr.StateEditFieldLabel.Position = [51 159 33 22];
gr.StateEditFieldLabel.Text = 'State';

% Create StateEditField
gr.StateEditField = uieditfield(gr.UIFigure, 'text');
gr.StateEditField.Position = [99 159 298 22];
gr.StateEditField.Value = 'Out of trial';

% Create photodiodesquarecolorLampLabel
gr.photodiodesquarecolorLampLabel = uilabel(gr.UIFigure);
gr.photodiodesquarecolorLampLabel.HorizontalAlignment = 'right';
gr.photodiodesquarecolorLampLabel.Position = [51 116 134 22];
gr.photodiodesquarecolorLampLabel.Text = 'photodiode square color';

% Create photodiodesquarecolorLamp
gr.photodiodesquarecolorLamp = uilamp(gr.UIFigure);
gr.photodiodesquarecolorLamp.Position = [195 117 20 20];
gr.photodiodesquarecolorLamp.Color = [0 0 0];

% Create TurnthisoffifthiswindowslowsdowngraphicsSwitchLabel
gr.TurnthisoffifthiswindowslowsdowngraphicsSwitchLabel = uilabel(gr.UIFigure);
gr.TurnthisoffifthiswindowslowsdowngraphicsSwitchLabel.HorizontalAlignment = 'center';
gr.TurnthisoffifthiswindowslowsdowngraphicsSwitchLabel.Position = [93 30 259 22];
gr.TurnthisoffifthiswindowslowsdowngraphicsSwitchLabel.Text = 'Turn this off if this window slows down graphics';

% Create TurnthisoffifthiswindowslowsdowngraphicsSwitch
gr.TurnthisoffifthiswindowslowsdowngraphicsSwitch = uiswitch(gr.UIFigure, 'slider');
gr.TurnthisoffifthiswindowslowsdowngraphicsSwitch.Position = [199 67 45 20];
gr.TurnthisoffifthiswindowslowsdowngraphicsSwitch.Value = 'On';

% Show the figure after all components are created
gr.UIFigure.Visible = 'on';
end
function updategui(gr)
if strcmp(gr.TurnthisoffifthiswindowslowsdowngraphicsSwitch.Value, 'Off')
    return;
end

gr.photodiodesquarecolorLamp.Color = gr.diode_color;
gr.StateEditField.Value = gr.activestatename;
eyepos = round(pix2deg(gr.eye.geteye, 'cart'), 1);
gr.xpositionEditField.Value = num2str(eyepos(1));
gr.ypositionEditField.Value = num2str(eyepos(2));
end
end
end


