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
% [screen info] is hand-written rig config; rigIni falls back to
% ScreenParams.ini on a rig that has not been migrated yet.
screenIni = rigIni('config', fullfile(pathhere,'inis'));
bgcolor = screenIni.GetValues('screen info','background');
gr = graphics;
gr.screenparams = screenIni; % previously wiped by the 'gr = graphics' line above
gr.eye=eyeinfo;

%% diagnostics log
% This process used to disp() into a terminal that dies with it, so a failed
% texture load or a dropped draw left no trace anywhere on disk and the only
% symptom was "nothing appears". Everything that went to the console now goes
% to a file next to the app's error logs as well.
grlogfid  = -1;
grlogLast = 0;
try
    logdir = fullfile(pathhere,'ErrorLogs');
    if ~exist(logdir,'dir'), mkdir(logdir); end
    grlogfid = fopen(fullfile(logdir, ...
        ['GraphicsHandler_' datestr(now,'yyyymmdd_HHMMSS') '.log']), 'w');
catch
end

%% set up the screens for experiments
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 3);

%set the resolution

% Clear the workspace and the screen
sca;
close all;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

%% display mode (the animal's TV) -- rig-specific, so read it from this rig's own ini
% rig1 drives a native 1080p60 panel and needs no mode change; rig2 drives a 4K
% panel that must be forced to 1920x1080@120. Missing keys mean "leave it alone".
displayXres    = screenIni.GetValues('screen info','display_xres');
displayYres    = screenIni.GetValues('screen info','display_yres');
displayRefresh = screenIni.GetValues('screen info','display_refresh');
if ~isempty(displayXres) && ~isempty(displayYres) && ~isempty(displayRefresh)
    Screen('Resolution', 1, displayXres, displayYres, displayRefresh);
    fprintf('display set to %gx%g @ %g Hz from ScreenParams.ini\n', displayXres, displayYres, displayRefresh);
else
    disp('no display_xres/display_yres/display_refresh in ScreenParams.ini; display mode left unchanged');
end

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
%% TESTING MOVIE LOGIC
% gr.movie = Screen('OpenMovie', gr.window_monitor, '/home/gandhilab/Documents/MATLAB/GandhiToolboxMERGER/Gandhi-PsychToolbox/Main code/assets/movie.mp4');
% disp('loaded movie')
% Screen('PlayMovie', gr.movie, 1);
%% keep function alive
% The scene is a LATEST-VALUE SLOT in shared memory, not a command queue.
% The state machine overwrites it as fast as it likes (measured ~39 us) and
% never waits; this loop reads whichever scene is current when it is ready to
% draw, at whatever rate Screen('Flip') allows. Scenes skipped in between
% were never displayable, so skipping them is correct and nothing backs up.
sceneMap = sceneOpen(false);
L        = sceneLayout();
flipcount = 0;
while 1
    try %error handler
        getCommands(graphicsport)          % low-rate control only (dumpdata, exit, seteye)

        [frame, ok] = sceneRead(sceneMap);
        if ~ok
            frame = struct('seq',-1,'trialStarted',false,'stateName','null', ...
                'setEye',false,'resources',{{}},'oneShots',{{}},'cmds',{{}});
        end

        gr.trialstarted = frame.trialStarted;

        % state name travels with the frame; diode flips on transition
        nm = frame.stateName;
        if isempty(nm), nm = 'null'; end
        if ~strcmp(gr.state_history{end}, nm)
            gr.state_history{end+1} = nm;
            gr.activestatename      = nm;
            gr.diode_color          = abs(gr.diode_color - 1);
            disp(join(["changed diode for state: " nm]));
        end

        if isfield(frame,'setEye') && frame.setEye
            try, seteye; catch, end
        end

        % Only a frame that was really read carries a sequence number. The state
        % machine numbers frames and one-shot tokens from zero each time it
        % starts, and this renderer outlives it, so a sequence number that goes
        % backwards means a fresh run whose tokens would otherwise sit below the
        % high-water mark and be ignored forever.
        if ok
            if frame.seq < gr.lastFrameSeq
                grlog('state machine restarted (seq %d -> %d); resetting one-shots', ...
                    gr.lastFrameSeq, frame.seq);
                gr.lastOneShot = 0;
            end
            gr.lastFrameSeq = frame.seq;
        end

        % load any texture or movie this renderer has not seen yet. The
        % declaration list rides in every frame, so this is idempotent and
        % there is no race over which frame happened to carry it.
        if isfield(frame,'resources') && ~isempty(frame.resources)
            ensureResources(gr, frame.resources);
        end
        runOneShots(gr, frame);

        if gr.trialstarted
            drawFrame(gr, frame);
            Screen('FillRect', gr.window_main, gr.diode_color, gr.diode_pos);
            Screen('DrawingFinished', gr.window_main);
            % Take the timestamps Psychtoolbox actually reports rather than
            % calling a clock afterwards: vbl/onset are when photons appeared,
            % and missed>0 means this flip overran its deadline.
            [vbl, onset, ~, missed] = Screen('Flip', gr.window_main);
            % frame.seq is the ID the state machine assigned when it generated
            % this command, so the two logs join on it.
            gr.commandIDs = [gr.commandIDs frame.seq];
            gr.fliptimes  = [gr.fliptimes  vbl];
            gr.flipOnsets = [gr.flipOnsets onset];
            gr.flipMissed = [gr.flipMissed missed];

            flipcount = flipcount + 1;
            if flipcount >= 3
                drawMonitorExtras(gr);
                Screen('Flip', gr.window_monitor, [], [], 1);   % dontsync: never block the display flip
                updategui(gr);
                flipcount = 0;
            end
        else
            % out of trial: show the eye and the grid on the monitor window
            writeline(graphicsport,'isGraphicsReady=1;','0.0.0.0',2020);
            gr = makegridlines(gr);
            try, seteye; catch, end
            setgrid(gr);
            try, Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]); catch, end

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

            Screen('Flip',gr.window_monitor, [], [], 1);
            Screen('Flip',gr.window_main);
            updategui(gr);
        end
    catch e
        grlog('LOOP ERROR: %s', e.message);
    end
end
%% diagnostics: console as before, plus a file that outlives this process
    function grlog(fmt, varargin)
        try
            msg = sprintf(fmt, varargin{:});
        catch
            msg = fmt;
        end
        disp(msg);
        if grlogfid > 0
            try
                fprintf(grlogfid, '%s  %s\n', datestr(now,'HH:MM:SS.FFF'), msg);
            catch
            end
        end
    end

    function grlogThrottled(fmt, varargin)
        % For conditions that repeat every frame: say it once a second rather
        % than 60 times, so the log stays readable but never goes silent.
        t = GetSecs;
        if t - grlogLast < 1, return; end
        grlogLast = t;
        grlog(fmt, varargin{:});
    end

%% low-rate control channel (still UDP: dumpdata, exit, seteye once a trial)
    function getCommands(graphicsport,~)
        try
            % NumBytesAvailable first: a bare readline blocks for the port
            % timeout (20 ms) when idle, which would cap this loop at 50 Hz.
            if graphicsport.NumBytesAvailable == 0
                return
            end
            command=readline(graphicsport);
            if strlength(command)==0
                return
            end
            if contains(command,'SetEye','IgnoreCase',true)
                seteye;
            elseif contains(command,'execute','IgnoreCase',true)
                rawexecute(command);
            end
        catch
        end
    end
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
        % char, not string: the command arrives as dumpdata("...") with double
        % quotes, so fname is a string scalar. [str 'suffix'] then builds a 1x2
        % STRING ARRAY instead of concatenating, which made save reject the
        % sidecar path with 'Argument must be a text scalar'.
        fname = char(strtrim(fname));

        % Snapshot and clear FIRST, before touching the file.
        %
        % The previous version cleared these buffers only AFTER a successful
        % load(). If the load threw, the data was neither written nor
        % cleared, so the next trial's dump wrote both trials' data into the
        % next trial's file - one trial empty, the following one doubled.
        % Clearing up front means a failed dump can lose at most the trial it
        % belongs to, and can never corrupt a second trial.
        rec = struct( ...
            'commandIDs', gr.commandIDs, ...   % which command IDs reached the screen
            'fliptimes',  gr.fliptimes,  ...   % VBL timestamp of each flip
            'onsets',     gr.flipOnsets, ...   % StimulusOnsetTime of each flip
            'missed',     gr.flipMissed, ...   % >0 means that flip overran its deadline
            'states',     {{gr.state_history{2:end}}});
        gr.commandIDs = []; gr.fliptimes = []; gr.flipOnsets = [];
        gr.flipMissed = []; gr.state_history = {'null'};

        for attempt = 1:3
            try
                temptr = load(fname);
                trname = fields(temptr);
                temptr.(trname{1}).data.graphics_fliptimes.commandIDs = rec.commandIDs;
                temptr.(trname{1}).data.graphics_fliptimes.fliptimes  = rec.fliptimes;
                temptr.(trname{1}).data.graphics_fliptimes.onsets     = rec.onsets;
                temptr.(trname{1}).data.graphics_fliptimes.missed     = rec.missed;
                temptr.(trname{1}).data.DiodeFlipStates               = rec.states;
                save(fname,'-struct','temptr');
                disp(join(['saved ', trname{1}]))
                return
            catch dumpErr
                disp(['dumpdata attempt ' num2str(attempt) ' failed: ' dumpErr.message]);
                pause(0.05);
            end
        end

        % Still could not write it. Spill to a sidecar next to the trial file
        % so the timing data is recoverable and unambiguously attributable,
        % instead of silently vanishing or landing in the wrong trial.
        try
            [pp,nn,~] = fileparts(fname);
            side = fullfile(pp, [nn '.graphics_orphan.mat']);
            save(side, 'rec');   % one struct variable: unambiguous, no -struct edge cases
            disp(['DUMPDATA FAILED - wrote orphan sidecar: ' side]);
        catch sideErr
            disp(['DUMPDATA FAILED and no sidecar could be written: ' sideErr.message]);
        end
    end
%%parse the commands without drawing'
%% draw the scene onto both windows
%% dispatch one frame's Screen calls onto the real windows
    function drawFrame(gr, frame)
        for i = 1:numel(frame.cmds)
            a = frame.cmds{i};
            if numel(a) < 2, continue; end
            nm = a{1};
            sel = a{2};
            if ~(ischar(sel) || isstring(sel))
                try, Screen(a{:}); catch e0, grlogThrottled('Screen(%s) failed: %s', char(string(nm)), e0.message); end
                continue
            end
            wantBoth    = strcmpi(string(sel), "both");
            wantDisplay = wantBoth || strcmpi(string(sel), "display");
            wantMonitor = wantBoth || strcmpi(string(sel), "monitor");
            if ~(wantDisplay || wantMonitor)
                try, Screen(a{:}); catch e3, grlogThrottled('Screen(%s) failed: %s', char(string(nm)), e3.message); end
                continue
            end
            if wantDisplay
                [rest, ok] = resolveArgs(gr, a(3:end), false);
                if ok
                    try, Screen(nm, gr.window_main, rest{:}); catch e1, grlogThrottled('display %s failed: %s', char(string(nm)), e1.message); end
                end
            end
            if wantMonitor
                [restM, okM] = resolveArgs(gr, a(3:end), true);
                if okM
                    try, Screen(nm, gr.window_monitor, restM{:}); catch e2, grlogThrottled('monitor %s failed: %s', char(string(nm)), e2.message); end
                end
            end
        end
    end

%% run each one-shot exactly once, no matter how many frames carried it
    function runOneShots(gr, frame)
        % Playback control changes renderer state rather than describing the
        % current picture, so it cannot be treated like a draw. This loop only
        % ever reads the NEWEST frame, so a command carried by a single frame
        % is almost always skipped -- which is why PlayMovie never arrived and
        % the movie sat on its first decoded frame. One-shots now ride in every
        % frame, tagged, and each token is run once.
        if ~isfield(frame,'oneShots') || isempty(frame.oneShots), return; end
        for i = 1:numel(frame.oneShots)
            s = frame.oneShots{i};
            if ~(isstruct(s) && isfield(s,'token') && isfield(s,'cmd')), continue; end
            if s.token <= gr.lastOneShot, continue; end
            gr.lastOneShot = s.token;           % consumed, whatever happens next
            a = s.cmd;
            if numel(a) < 3 || ~(isstruct(a{3}) && isfield(a{3},'resref')), continue; end
            nm = a{1};
            id = a{3}.resref;
            if ~(numel(gr.resourceKind) >= id && strcmp(gr.resourceKind{id},'movie'))
                grlog('%s skipped: id=%d is not a loaded movie', char(nm), id);
                continue
            end
            % PlayMovie/CloseMovie take a MOVIE handle, not a window pointer
            rate = 1;
            if strcmpi(string(nm),"CloseMovie"), rate = 0; end
            if numel(a) >= 4 && isnumeric(a{4}) && isscalar(a{4}), rate = a{4}; end
            try
                Screen('PlayMovie', gr.resourceMap(id), rate);
                grlog('%s id=%d rate=%g', char(nm), id, rate);
            catch pmErr
                grlog('%s FAILED id=%d: %s', char(nm), id, pmErr.message);
            end
        end
    end

%% load any resource this renderer has not seen yet
    function ensureResources(gr, decls)
        for i = 1:numel(decls)
            d = decls{i};
            % A logical id only means something within ONE run of the state
            % machine: ids are handed out 1,2,3... per run, while this renderer
            % keeps its cache across restarts of that process. Keying the cache
            % on the id alone let a texture resolve against a movie left over
            % from an earlier run, and a movie against a leftover texture -- so
            % the texture drew nothing and the movie drew a stale still frame.
            % The id is trusted only while the declaration still agrees about
            % what it points at.
            if cachedMatches(gr, d)
                continue                        % already loaded, or already failed
            end
            releaseResource(gr, d.id);          % id recycled: let the old one go
            try
                switch d.kind
                    case 'texture'
                        img = imread(d.path);
                        % A Psychtoolbox texture belongs to the window it was
                        % made for, so the experimenter's window needs its own.
                        gr.resourceMap(d.id)    = Screen('MakeTexture', gr.window_main,    img);
                        gr.resourceMapMon(d.id) = Screen('MakeTexture', gr.window_monitor, img);
                        gr.resourceKind{d.id}   = 'texture';
                        grlog('loaded texture id=%d: %s', d.id, d.path);
                    case 'movie'
                        gr.resourceMap(d.id)    = Screen('OpenMovie', gr.window_main, d.path);
                        gr.resourceMapMon(d.id) = 0;     % decoded once, shown on the display
                        gr.resourceKind{d.id}   = 'movie';
                        grlog('opened movie id=%d: %s', d.id, d.path);
                    otherwise
                        gr.resourceKind{d.id}   = 'failed';
                        grlog('UNKNOWN RESOURCE KIND "%s" id=%d', char(d.kind), d.id);
                end
            catch resErr
                gr.resourceMap(d.id)  = -1;     % mark failed so we stop retrying every frame
                gr.resourceKind{d.id} = 'failed';
                grlog('RESOURCE LOAD FAILED id=%d (%s): %s', d.id, d.path, resErr.message);
            end
            gr.resourcePath{d.id} = d.path;     % what this id now stands for
        end
    end

%% is the cached entry for this id still the thing the task is asking for?
    function tf = cachedMatches(gr, d)
        tf = numel(gr.resourceKind) >= d.id && ~isempty(gr.resourceKind{d.id}) ...
            && numel(gr.resourcePath) >= d.id ...
            && strcmp(gr.resourcePath{d.id}, d.path) ...
            && (strcmp(gr.resourceKind{d.id}, d.kind) ...
                || strcmp(gr.resourceKind{d.id}, 'failed'));
    end

%% free whatever an id used to hold, before it is reused for something else
    function releaseResource(gr, id)
        if numel(gr.resourceKind) < id || isempty(gr.resourceKind{id}), return; end
        try
            switch gr.resourceKind{id}
                case 'texture'
                    if gr.resourceMap(id)    > 0, Screen('Close', gr.resourceMap(id));    end
                    if gr.resourceMapMon(id) > 0, Screen('Close', gr.resourceMapMon(id)); end
                case 'movie'
                    if numel(gr.movieLastTex) >= id && gr.movieLastTex(id) > 0
                        Screen('Close', gr.movieLastTex(id));
                    end
                    Screen('CloseMovie', gr.resourceMap(id));
            end
            grlog('released stale resource id=%d (%s)', id, gr.resourceKind{id});
        catch relErr
            grlog('could not release id=%d: %s', id, relErr.message);
        end
        gr.resourceKind{id} = '';
        if numel(gr.movieLastTex) >= id, gr.movieLastTex(id) = 0; end
    end

%% turn resource references into handles valid for the requested window
    function [rest, ok] = resolveArgs(gr, rest, wantMonitor)
        ok = true;
        for j = 1:numel(rest)
            if ~(isstruct(rest{j}) && isfield(rest{j},'resref')), continue; end
            id = rest{j}.resref;
            if numel(gr.resourceKind) < id || isempty(gr.resourceKind{id}) || strcmp(gr.resourceKind{id},'failed')
                % Dropping the draw is right -- there is nothing to draw yet --
                % but doing it silently is what made a failed load look like a
                % task that simply does nothing.
                grlogThrottled('draw dropped: resource id=%d not available', id);
                ok = false; return                      % not loaded, or failed
            end
            if strcmp(gr.resourceKind{id}, 'movie')
                % The experimenter's window shows the movie too. Textures are
                % shared between the two windows on this rig, so the monitor
                % reuses the frame the display just decoded - one decode, two
                % draws. drawFrame resolves the display first, so by the time
                % the monitor asks, movieLastTex already holds this frame.
                % Movies advance at the renderer's rate. GetMovieImage with
                % waitForImage=0 returns 0 when no NEW frame is ready, which is
                % most flips for a 30 fps movie on a 60 Hz panel - so keep the
                % last frame and redraw it instead of flickering.
                try
                    t = Screen('GetMovieImage', gr.window_main, gr.resourceMap(id), 0);
                catch gmErr
                    % A stale handle used to throw out of here and abort the
                    % whole frame, so one bad movie blanked everything.
                    grlogThrottled('GetMovieImage failed for id=%d: %s', id, gmErr.message);
                    ok = false; return
                end
                if t > 0
                    if numel(gr.movieLastTex) >= id && gr.movieLastTex(id) > 0
                        try, Screen('Close', gr.movieLastTex(id)); catch, end
                    end
                    gr.movieLastTex(id) = t;
                end
                if numel(gr.movieLastTex) < id || gr.movieLastTex(id) <= 0
                    ok = false; return                  % nothing decoded yet
                end
                rest{j} = gr.movieLastTex(id);
            elseif wantMonitor
                rest{j} = gr.resourceMapMon(id);
            else
                rest{j} = gr.resourceMap(id);
            end
        end
    end


%% monitor-only furniture: grid and eye position
    function drawMonitorExtras(gr)
        setgrid(gr);
        try, Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]); catch, end
        Screen('FillRect', gr.window_monitor, gr.diode_color, gr.diode_pos);
    end

    function gr=makegridlines(gr)
        gr.pixelsforlines=deg2pix(gr.toconvert,'cart');
        gr.xlines=reshape(repmat(gr.pixelsforlines(:,1),2)',1,[]);
        fully=reshape(repmat([0 1080], length(gr.xlines)/2,1)',1,[]);
        gr.ylines = reshape(repmat(gr.pixelsforlines(:,2),2)',1,[]);
        fullx=reshape(repmat([0 3000], length(gr.ylines)/2,1)',1,[]);
        gr.gridlinesmatrix=[gr.xlines fullx;fully gr.ylines];
        truezero=deg2pix([0 0]);
        circdegrees=(1:gr.circleadder:90)-1;
        degadds=deg2pix(repmat(circdegrees',1,2),'cart')-truezero;
        degadds(:,2)=[];

        gr.center_circle=[truezero-10 truezero+10;...
            truezero-degadds truezero+degadds]';
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
        if strcmp(gr.TurnthisoffifthiswindowslowsdowngraphicsSwitch.Value,'On')
            gr.photodiodesquarecolorLamp.Color = gr.diode_color;
            gr.StateEditField.Value = gr.activestatename;
            eyepos=round(pix2deg(gr.eye.geteye,'cart'),1);
            gr.xpositionEditField.Value=num2str(eyepos(1));
            gr.ypositionEditField.Value=num2str(eyepos(2));
        else
            % gr.xpositionEditField.Value='off';
            % gr.ypositionEditField.Value='off';
            % gr.StateEditField.Value = 'out of trial';
        end
    end
end
