function GraphicsHandler
% opengl('save','hardware');

% GStreamer's VA-API plugin segfaults inside the AMD driver (libgstvaapi ->
% vaInitialize -> radeonsi_drv_video -> LLVM) while opening a movie, taking
% this whole process with it -- intermittently, which is why it looked like
% random renderer deaths (~/matlab_crash_dump.*, thread 'qtdemux0:sink').
% Point libva at a driver that does not exist: vaInitialize then fails
% cleanly, the vaapi elements never register, and GStreamer decodes in
% software, which is what every run that did not crash was doing anyway.
% Must happen before Psychtoolbox initialises GStreamer (first OpenMovie).
setenv('LIBVA_DRIVER_NAME', 'none');
setenv('GST_PLUGIN_FEATURE_RANK', 'vaapidecodebin:0,vaapih264dec:0,vaapih265dec:0,vaapimpeg2dec:0,vaapivp8dec:0,vaapivp9dec:0,vaapipostproc:0,vaapisink:0');

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
% Whatever the slot holds now predates this renderer. Take its state as the
% baseline rather than recording it as the first trial's first transition.
[frame0, ok0] = sceneRead(sceneMap);
if ok0 && isfield(frame0,'stateName') && ~isempty(frame0.stateName)
    gr.state_history   = {char(frame0.stateName)};
    gr.activestatename = char(frame0.stateName);
end
% Flip-rate gauge for the state machine's GUI: the scene slot's format in the
% opposite direction. This process is the only writer; the state machine
% reads whichever value is current when it refreshes its misc tab.
statsMap   = sceneOpen(true, renderStatsPath());
statsSeq   = 0;
statsLastT = 0;
vblRing    = nan(1,120);            % last ~2 s of display flips at 60 Hz
% Mouse mode: publish the cursor (in the monitor window) as a simulated eye
% position. The slot is created lazily on first use, so normal sessions never
% touch it. heldX/heldY latch the last position so the eye only moves while the
% left button is held.
mouseMap = []; mouseSeq = 0; heldX = []; heldY = [];
% Keep the monitor window a fixed size: PTB has no non-resizable GUI flag, so
% if the operator resizes it we snap the size back (position left free, so it
% stays movable). Target size is captured on the first idle frame.
monTargetW = []; monTargetH = []; lastSnapT = 0;
while 1
    try %error handler
        getCommands(graphicsport)          % low-rate control only (dumpdata, exit, seteye)

        % Mouse mode (toggled via evalgraphics gr.mousemode): map the cursor in
        % the monitor window to DISPLAY pixels and publish it as the eye
        % position. The eye follows the cursor only while the LEFT button is
        % held, so releasing it freezes the eye instead of snapping to an edge.
        if isprop(gr,'mousemode') && gr.mousemode
            tgt = 'eye'; if isprop(gr,'mousetarget'), tgt = gr.mousetarget; end   % eye or cursorN
            if isempty(mouseMap), mouseMap = sceneOpen(true, mousePath()); end
            [mmx, mmy, mbtn] = GetMouse(gr.window_monitor);
            r = Screen('Rect', gr.window_monitor);          % window-local pixels
            dx = (mmx - r(1)) / max(1, r(3)-r(1)) * gr.screenXpixels;   % -> display px
            dy = (mmy - r(2)) / max(1, r(4)-r(2)) * gr.screenYpixels;
            if isempty(heldX), heldX = dx; heldY = dy; end  % start at the cursor
            if mbtn(1), heldX = dx; heldY = dy; end          % move only while left held
            mouseSeq = mouseSeq + 1;
            sceneWrite(mouseMap, mouseSeq, struct('on',1,'target',tgt,'x',heldX,'y',heldY));
        elseif ~isempty(mouseMap)
            mouseSeq = mouseSeq + 1;
            sceneWrite(mouseMap, mouseSeq, struct('on',0,'target','eye','x',0,'y',0));   % announce off
            heldX = []; heldY = [];
        end

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
            noteDisplayFlip(vbl);
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
                % Service the Graphics Info uifigure's event queue so it renders
                % and stays interactive; throttled, and only when the info window
                % is enabled, so it never disturbs display-flip timing otherwise.
                if strcmp(gr.TurnthisoffifthiswindowslowsdowngraphicsSwitch.Value,'On'), drawnow limitrate; end
                flipcount = 0;
            end
        else
            % out of trial: show the eye and the grid on the monitor window
            writeline(graphicsport,'isGraphicsReady=1;','0.0.0.0',2020);
            gr = makegridlines(gr);
            try, seteye; catch, end
            setgrid(gr);
            try, Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]); catch, end
            drawcursors(gr);

            gr.newsize=Screen('GlobalRect',gr.window_monitor);
            gr.newsize_true(1)=gr.newsize(3)-gr.newsize(1);
            gr.newsize_true(2)=gr.newsize(4)-gr.newsize(2);
            % Fixed-size monitor window: if it was resized, snap the size back
            % (leave X/Y at -1 = unchanged, so it can still be moved). wmctrl
            % runs in the background and is rate-limited so it never stalls the
            % loop or oscillates. Target = the size the window opened at.
            if isempty(monTargetW), monTargetW = gr.newsize_true(1); monTargetH = gr.newsize_true(2); end
            if (abs(gr.newsize_true(1)-monTargetW) > 8 || abs(gr.newsize_true(2)-monTargetH) > 8) && (GetSecs - lastSnapT > 1)
                lastSnapT = GetSecs;
                try
                    system(sprintf('wmctrl -r "PTB Onscreen Window [%d]" -e 0,-1,-1,%d,%d &', ...
                        gr.window_monitor, monTargetW, monTargetH));
                catch
                end
            end
            % Only re-drive the PanelFitter when a pan/zoom is actually pending.
            % The window opened with UsePanelFitter(...,'Full'), which re-fits the
            % content to the window on its own; overriding it every frame pinned a
            % stale source/dest rect, so a plain OS resize tiled instead of
            % re-fitting. Leaving it alone unless the operator panned/zoomed lets
            % resize work while preserving pan/zoom.
            if gr.scalefactor ~= 1 || gr.left_right ~= 0 || gr.up_down ~= 0
                gr.winparams=Screen('PanelFitter', gr.window_monitor);
                gr.winparams(1:4)=ceil(gr.winparams(1:4)*gr.scalefactor);
                gr.scalefactor=1;
                gr.winparams([1,3])=ceil(gr.winparams([1,3])+gr.left_right);
                gr.left_right=0;
                gr.winparams([2,4])=ceil(gr.winparams([2,4])+gr.up_down);
                gr.up_down=0;
                Screen('PanelFitter', gr.window_monitor, gr.winparams);
            end

            Screen('Flip',gr.window_monitor, [], [], 1);
            vblIdle = Screen('Flip',gr.window_main);
            noteDisplayFlip(vblIdle);
            updategui(gr);
            drawnow limitrate;   % out of trial: keep the info window painted & interactive (timing not critical here)
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
            % The monitor grid (degrees + mm) is rebuilt every frame by
            % makegridlines, so there is nothing else to do here.
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
        gr.flipMissed = [];
        % Keep the current state as the new baseline (element 1 is never
        % recorded). Resetting to 'null' made the next iteration see the
        % previous trial's still-current 'stop_autogenerated' as a fresh
        % transition: it led every trial's DiodeFlipStates and toggled the
        % diode once between trials, offsetting the whole list by one.
        gr.state_history = gr.state_history(end);

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
            % A resource reference (a struct with .resref) is only ever a
            % handle in THIS process, and is resolved only on the windowed
            % branches below. If one reaches a fall-through Screen(a{:}) path
            % (an unrecognised window selector), passing the struct into the
            % Screen mex corrupts its argument parser so that every later
            % Screen call, on any window, then fails with a bare "Usage:"
            % until the process is restarted. So on those paths, drop the
            % command instead of poisoning the mex.
            if ~(ischar(sel) || isstring(sel))
                if hasResref(a), grlogThrottled('dropped %s: unresolved resource ref', char(string(nm))); continue; end
                try, Screen(a{:}); catch e0, grlogThrottled('Screen(%s) failed: %s', char(string(nm)), e0.message); end
                continue
            end
            wantBoth    = strcmpi(string(sel), "both");
            wantDisplay = wantBoth || strcmpi(string(sel), "display");
            wantMonitor = wantBoth || strcmpi(string(sel), "monitor");
            if ~(wantDisplay || wantMonitor)
                if hasResref(a), grlogThrottled('dropped %s: resource ref with unknown window selector "%s"', char(string(nm)), char(string(sel))); continue; end
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

%% does this command still carry an unresolved resource reference?
    function tf = hasResref(a)
        tf = false;
        for k = 1:numel(a)
            if isstruct(a{k}) && isfield(a{k}, 'resref'), tf = true; return; end
        end
    end

%% publish the display flip rate about once a second
    function noteDisplayFlip(vbl)
        vblRing = [vblRing(2:end) vbl];
        if vbl - statsLastT < 1, return; end
        statsLastT = vbl;
        v = vblRing(~isnan(vblRing));
        if numel(v) < 2, return; end
        statsSeq = statsSeq + 1;
        try
            sceneWrite(statsMap, statsSeq, struct( ...
                'fps',          (numel(v)-1) / (v(end)-v(1)), ...
                'nFlips',       numel(v), ...
                'trialStarted', logical(gr.trialstarted), ...
                't',            vbl));
        catch stErr
            grlogThrottled('flip-rate publish failed: %s', stErr.message);
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
            % Movies play CONTINUOUSLY (opened, looping and muted, in
            % ensureResources) and are never paused. Pausing then resuming is
            % where GStreamer stalls on this rig -- bare PlayMovie sometimes
            % never restarts the decoder, so the movie sits frozen on its last
            % frame, intermittently and worsening over a session (the
            % ~19-trial freeze). Every mitigation for the resume (flush-seek,
            % blocking re-prime) still left a stall under rapid switching, and
            % the blocking prime stuttered the vsync loop. Not pausing removes
            % the whole failure class: 0 freezes across rapid and normal
            % timing. The task decides what the animal SEES by whether it
            % draws the movie, not by starting/stopping the decoder.
            if strcmpi(string(nm), "SetMovieTimeIndex")
                % Seek an already-playing movie -- reliable, and instant once
                % warmupMovie has built the seek index. Applied to both copies.
                secs = 0;
                if numel(a) >= 4 && isnumeric(a{4}) && isscalar(a{4}), secs = a{4}; end
                try
                    Screen('SetMovieTimeIndex', gr.resourceMap(id), secs);
                    if ~isnan(gr.resourceMapMon(id))
                        Screen('SetMovieTimeIndex', gr.resourceMapMon(id), secs);
                    end
                    grlog('SetMovieTimeIndex id=%d t=%g s', id, secs);
                catch skErr
                    grlog('SetMovieTimeIndex FAILED id=%d: %s', id, skErr.message);
                end
                continue
            end
            % PlayMovie re-asserts continuous playback (idempotent -- the
            % movie is already playing); CloseMovie is intentionally a no-op
            % for the decoder (it does NOT pause), since the task stops
            % showing the movie simply by not drawing it. Both are kept so the
            % task API is unchanged and so a rate change (e.g. slow motion via
            % PlayMovie rate) still takes effect.
            if strcmpi(string(nm), "CloseMovie")
                grlog('CloseMovie id=%d (no-op; movie plays continuously)', id);
                continue
            end
            rate = 1;
            if numel(a) >= 4 && isnumeric(a{4}) && isscalar(a{4}), rate = a{4}; end
            try
                Screen('PlayMovie', gr.resourceMap(id), rate, 1, 0);   % loop, muted
                grlog('PlayMovie id=%d rate=%g', id, rate);
            catch pmErr
                grlog('PlayMovie FAILED id=%d: %s', id, pmErr.message);
            end
            if ~isnan(gr.resourceMapMon(id))
                try
                    Screen('PlayMovie', gr.resourceMapMon(id), rate, 1, 0);
                catch pmErrM
                    grlog('PlayMovie FAILED on monitor copy id=%d: %s', id, pmErrM.message);
                end
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
                        % A decoded movie frame is a texture and, like any
                        % texture, belongs to the window it was decoded for:
                        % the display's frame drawn on the monitor renders
                        % solid white (measured by pixel readback; the
                        % earlier check only saw that the call did not
                        % throw). So the monitor decodes its own copy. That
                        % costs 0.08 ms/frame against a 16.67 ms budget.
                        [gr.resourceMap(d.id), durS] = Screen('OpenMovie', gr.window_main, d.path);
                        gr.resourceKind{d.id}   = 'movie';
                        grlog('opened movie id=%d: %s', d.id, d.path);
                        gr.movieLastTex(d.id)    = 0;
                        gr.movieLastTexMon(d.id) = 0;
                        warmupMovie(gr.window_main, gr.resourceMap(d.id), durS, d.id, 'display');
                        % Then leave it PLAYING for good: looping so a long
                        % session never runs off the end, muted so it makes no
                        % sound while the task is not showing it. The task
                        % never pauses it; see runOneShots.
                        Screen('PlayMovie', gr.resourceMap(d.id), 1, 1, 0);
                        try
                            [gr.resourceMapMon(d.id), durM] = Screen('OpenMovie', gr.window_monitor, d.path);
                            warmupMovie(gr.window_monitor, gr.resourceMapMon(d.id), durM, d.id, 'monitor');
                            Screen('PlayMovie', gr.resourceMapMon(d.id), 1, 1, 0);
                        catch monErr
                            % The display copy is the one that matters;
                            % NaN (a valid movie handle can be 0) means the
                            % monitor simply has nothing to draw for it.
                            gr.resourceMapMon(d.id) = NaN;
                            grlog('monitor copy of movie id=%d failed to open: %s', d.id, monErr.message);
                        end
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

%% prime a just-opened movie so the first trial is not the slow one
    function warmupMovie(win, mov, durS, id, which)
        % qtdemux builds its seek index on the FIRST real (non-zero) seek of a
        % movie handle. Without this, trial 1 of a task that seeks
        % (SetMovieTimeIndex) decodes at roughly half rate while that index is
        % built, so the movie looks stuck for a trial or two before it runs
        % smoothly. Doing one real seek here, once at open, moves that cost off
        % the experiment: measured, trial 1 then decodes at full rate like the
        % rest. A seek to 0 does NOT exercise the index, so the target must be
        % non-zero; clamp it inside the movie for very short clips.
        if isempty(durS) || ~isfinite(durS) || durS <= 0, durS = 2; end
        warmT = max(0.1, min(1.0, durS/2));
        try
            Screen('PlayMovie', mov, 1, 0, 0);   % muted: warmup makes no sound
            pullBounded(win, mov, 0.5);
            Screen('SetMovieTimeIndex', mov, warmT);   % the real seek that builds the index
            pullBounded(win, mov, 0.5);
            Screen('SetMovieTimeIndex', mov, 0);       % leave it where a fresh open would
            pullBounded(win, mov, 0.5);
            Screen('PlayMovie', mov, 0);               % back to paused, as opened
            grlog('warmed up %s movie id=%d (dur=%.1fs, seek probe %.2fs)', which, id, durS, warmT);
        catch wErr
            % Warmup is best-effort: a failure here only means trial 1 is the
            % slow one again, not that the movie is broken.
            grlogThrottled('movie warmup (%s) id=%d failed: %s', which, id, wErr.message);
        end
    end

%% pull decoded frames for up to timeoutS, discarding them (warmup only)
    function pullBounded(win, mov, timeoutS)
        t0 = GetSecs;
        got = false;
        while GetSecs - t0 < timeoutS
            t = Screen('GetMovieImage', win, mov, 0);
            if t > 0, Screen('Close', t); got = true; break; end
        end
        if ~got
            % one blocking pull as a fallback, itself guarded by the caller
            t = Screen('GetMovieImage', win, mov, 1);
            if t > 0, Screen('Close', t); end
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
                    if numel(gr.movieLastTexMon) >= id && gr.movieLastTexMon(id) > 0
                        Screen('Close', gr.movieLastTexMon(id));
                    end
                    Screen('CloseMovie', gr.resourceMap(id));
                    if ~isnan(gr.resourceMapMon(id))
                        Screen('CloseMovie', gr.resourceMapMon(id));
                    end
            end
            grlog('released stale resource id=%d (%s)', id, gr.resourceKind{id});
        catch relErr
            grlog('could not release id=%d: %s', id, relErr.message);
        end
        gr.resourceKind{id} = '';
        if numel(gr.movieLastTex)    >= id, gr.movieLastTex(id)    = 0; end
        if numel(gr.movieLastTexMon) >= id, gr.movieLastTexMon(id) = 0; end
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
                % Each window decodes its own copy of the movie (see
                % ensureResources), so ask the copy that belongs to the
                % window being drawn.
                [tex, have] = movieFrame(gr, id, wantMonitor);
                if ~have
                    ok = false; return                  % nothing decoded yet
                end
                rest{j} = tex;
            elseif wantMonitor
                rest{j} = gr.resourceMapMon(id);
            else
                rest{j} = gr.resourceMap(id);
            end
        end
    end

%% newest decoded frame of movie id for one window, or its previous frame
    function [tex, have] = movieFrame(gr, id, wantMonitor)
        % Movies advance at the renderer's rate. GetMovieImage with
        % waitForImage=0 returns 0 when no NEW frame is ready, which is most
        % flips for a 30 fps movie on a 60 Hz panel - so keep the last frame
        % and redraw it instead of flickering.
        tex = 0; have = false;
        if wantMonitor
            win = gr.window_monitor; mov = gr.resourceMapMon(id); last = gr.movieLastTexMon;
        else
            win = gr.window_main;    mov = gr.resourceMap(id);    last = gr.movieLastTex;
        end
        if isnan(mov), return; end              % this window has no copy
        try
            t = Screen('GetMovieImage', win, mov, 0);
        catch gmErr
            % A stale handle used to throw out of here and abort the whole
            % frame, so one bad movie blanked everything.
            grlogThrottled('GetMovieImage failed for id=%d: %s', id, gmErr.message);
            return
        end
        if t > 0
            if numel(last) >= id && last(id) > 0
                try, Screen('Close', last(id)); catch, end
            end
            last(id) = t;
            if wantMonitor, gr.movieLastTexMon = last; else, gr.movieLastTex = last; end
        end
        if numel(last) < id || last(id) <= 0, return; end
        tex = last(id); have = true;
    end


%% monitor-only furniture: grid and eye position
    function drawMonitorExtras(gr)
        setgrid(gr);
        try, Screen('DrawDots', gr.window_monitor, gr.eye.geteye, 10 , [255,255,255]); catch, end
        drawcursors(gr);
        Screen('FillRect', gr.window_monitor, gr.diode_color, gr.diode_pos);
    end

    function drawcursors(grobj)
        % Draw each ACTIVE cursor on the monitor as a coloured dot (distinct
        % from the white eye dot). "Active" = a cursor the mouse is driving in
        % mouse mode, or an enabled (assigned) analog cursor. UDP cursors are
        % skipped here so the renderer never binds the port the task process
        % already listens on; a mouse-driven cursor reads the shared mouse slot.
        if isempty(grobj.cursors)
            grobj.cursors = cell(1,5);
            for ci = 1:5, grobj.cursors{ci} = cursorinfo(ci); end
        end
        cols = [0 255 255; 255 0 255; 255 255 0; 255 160 0; 120 255 120];
        W = grobj.screenXpixels; H = grobj.screenYpixels; m = 12;   % edge margin
        for ci = 1:5
            c = grobj.cursors{ci};
            active = c.enabled && ~strcmpi(c.source,'udp');
            if isprop(grobj,'mousemode') && grobj.mousemode && ...
               strcmpi(grobj.mousetarget, sprintf('cursor%d',ci))
                active = true;   % mouse mode is driving this cursor
            end
            if ~active, continue; end
            try
                p = c.getcursor; px = p(1); py = p(2);
                offscreen = px < 0 || px > W || py < 0 || py > H;
                cx = min(max(px, m), W-m);   % clamp the drawn dot to the screen
                cy = min(max(py, m), H-m);   % so an off-screen cursor is findable
                Screen('DrawDots', grobj.window_monitor, [cx; cy], 14, cols(ci,:), [], 2);
                if offscreen
                    % pin to the edge and label with its real coordinates (deg)
                    dg = pix2deg([px py], 'cart');
                    Screen('TextSize', grobj.window_monitor, grobj.fontsize);
                    Screen('DrawText', grobj.window_monitor, ...
                        sprintf('c%d off (%.1f, %.1f)', ci, dg(1), dg(2)), ...
                        min(max(cx+10, 2), W-160), min(max(cy-10, 12), H-12), cols(ci,:));
                end
            catch
            end
        end
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

        % mm grid (spacing gr.mmgrid mm; linear via deg2pix ...,'mm'), drawn
        % when gridmode is 'mm' or 'both'. Spans ~700 mm each way to cover the
        % panel about the true center.
        mmspan = ceil(700/gr.mmgrid)*gr.mmgrid;
        gr.mmvals = -mmspan:gr.mmgrid:mmspan;
        gr.mmpixels = deg2pix([gr.mmvals(:) gr.mmvals(:)],'mm');
        mmx = reshape(repmat(gr.mmpixels(:,1),2)',1,[]);
        mmfully = reshape(repmat([0 1080], length(mmx)/2,1)',1,[]);
        mmy = reshape(repmat(gr.mmpixels(:,2),2)',1,[]);
        mmfullx = reshape(repmat([0 3000], length(mmy)/2,1)',1,[]);
        gr.gridlinesmatrix_mm = [mmx mmfullx; mmfully mmy];
    end
%%set grid
    function gr=setgrid(gr)
        Screen('TextSize', gr.window_monitor,gr.fontsize);
        gm = gr.gridmode; if isempty(gm), gm='degrees'; end
        try
            Screen('DrawText', gr.window_monitor, num2str(round(pix2deg(gr.eye.geteye,'cart'),1)), 960, 5 , [255,255,255]);
        catch
        end
        if any(strcmpi(gm,{'degrees','both'}))
            try
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
        if any(strcmpi(gm,{'mm','both'}))
            try
                for i=1:length(gr.mmvals)
                    Screen('DrawText', gr.window_monitor, num2str(gr.mmvals(i)), gr.mmpixels(i,1),...
                        gr.mmpixels(ceil(length(gr.mmvals)/2),2), [.4,.4,.7]);
                    Screen('DrawText', gr.window_monitor, num2str(gr.mmvals(i)),...
                        gr.mmpixels(ceil(length(gr.mmvals)/2),1), gr.mmpixels(i,2), [.4,.4,.7]);
                end
            catch
            end
            Screen('DrawLines',gr.window_monitor,gr.gridlinesmatrix_mm,1,[.25 .25 .5]);
        end
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

        % Create Grid units dropdown (switch the monitor grid: degrees / mm / both)
        gridLbl = uilabel(gr.UIFigure);
        gridLbl.HorizontalAlignment = 'right';
        gridLbl.Position = [222 138 68 22];
        gridLbl.Text = 'Grid units';
        gridDD = uidropdown(gr.UIFigure);
        gridDD.Items = {'degrees', 'mm', 'both'};
        gridDD.Position = [295 138 105 22];
        gridDD.Value = gr.gridmode;
        gridDD.ValueChangedFcn = @(src,~) gr.setgridmode(src.Value);

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
