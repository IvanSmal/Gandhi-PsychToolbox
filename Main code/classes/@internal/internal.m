classdef internal < matlab.mixin.Copyable
    %INTERNAL Summary of this class goes here
    %   Detailed explanation goes here

    properties
        %% trial properties to pick from. This is user-defined parameters
        intervals
        targets % database of targets to use in tasks

        % movie and texture
        movie
        tex

        %trial metadata properties (can these be combined?)
        trial = trial;
        runtrial
        trialstarted = 0
        trialnumpersistent=0;
        tlogic
        trial_function
        sum_success=0;

        %diode properties
        diode_pos = [0,1300 ,50, 1350];
        diode_on = 0;
        diode_color= [1,1,1];

        % for eye movement detection
        eye;
        cursors = {};                % cursorinfo objects (1..5): mm-calibrated pointers tracked alongside the eye
        checkcursor_counter = {};    % per-cursor 3-sample grace counter (parallel to checkeye_counter)
        targhistory=zeros(4,10);
        autocalibrationmatrix=[];
        autocalibrationmatrix_buffer=[];
        autocalibrationtrials=0;
        screenparams;
        
        %reward
        rew = struct('rewon',0);
        rewardport;
        rewardcount=0;

        % For statechanges and diode flips
        activestatetime=[]   % GetSecs when the current state began (checkint)
        activestatename = 'null';
        targettime           % GetSecs: start of the state a moving target's path is timed from (getpos)


        % trialtypes logic table
        ttypeslogic
        failcounter

        %collision stuff
        coltimer=0

        %eccentricity gain and target trails
        eccentricity_gain;
        trailing_window_time;

        %communicate with graphics
        graphicsport;
        graphicssent=0
        cachedout = 'default'
        graphicscommandbuffer=''; %graphics buffer. move to private later
        lastcommand = 1; %move to private later
        holdbuffer = 0;
        readyforflip=1;
        commandID=0;

        %shared-memory scene channel (replaces the UDP command stream).
        %The state machine overwrites a fixed binary slot; GraphicsHandler
        %reads the newest complete scene at its own refresh rate. Writer
        %never blocks on the renderer, so the two rates are independent.
        sceneMap;            % memmapfile handle, writable
        cmdList;             % commands accumulated for the frame being built
        sceneSeq = 0;        % monotonically increasing sequence number


        sceneSetEye = 0;     % one-shot: tell graphics to reload eye calibration

        %stimulus timing (see buildStimulusTiming). Each published frame lists
        %the items it draws on the display: targets (matched through the
        %rectangle getpos returned) and mh.Screen(..., 'Tag', name) commands;
        %frameItems keeps that list and spots the changes. publishFrame logs
        %every change - an item appearing or disappearing, a state change -
        %here, with the frame's ID and GetSecs time; GraphicsHandler later
        %matches those to the flips that showed them. Changes are rare, so
        %the log grows on demand.
        stimFirstSeq  = 0;       % first frame ID of this trial

        %repeating a failed trial exactly: the trial's parameters as they were
        %when its setup block ended (setstate takes it at the first state after
        %starttrial, on a first attempt only). MHost2 restores it for a repeat.
        trialSnapshot   = [];    % ttype, trialnum, firstState, targets, intervals, userdefined
        snapshotPending = false; % starttrial sets it; the next setstate takes the snapshot
        stimReqN      = 0;       % change log: entries used
        stimReqTag    = {};
        stimReqKind   = {};
        stimReqEvent  = {};
        stimReqState  = {};
        stimReqSeq    = [];
        stimReqTime   = [];      % GetSecs of the frame (trialRecord: requested_ms)
        stimReqToken  = [];      % movie seek / play: the one-shot's token (matched to the renderer's log)
        stimReqValue  = [];      % movie seek: target time (s); play: rate

        %texture and movie resources. Declared by name in the parameter file
        %(addtexture/addmovie), grabbed once per trial in the task's setup
        %block (gettexture/getmovie). Psychtoolbox handles are only valid in
        %the process that created them, so the state machine holds paths and
        %logical ids while GraphicsHandler holds the real handles.
        textures     = struct();   % name -> image path
        movies       = struct();   % name -> movie path
        resourceIds  = struct();   % kind_name -> logical id
        resourceDecl = {};         % declarations, carried in every frame
        nextResId    = 0;
        oneShots     = {};         % PlayMovie/CloseMovie etc: ride every frame until run
        oneShotSeq   = 0;          % monotonic token, never reset within a session
            
        %stim stuff
        stimmed=0;
        stimflip=0;

        %user definitions
        userdefined=0;

        %live parameter tables
        targtable;
        intervaltable;

    end

    properties (Access=private)
        checkeye_counter=[0,0,0]; % grace period of 3 samples for eye to be in
    end

    methods      

    end
end

