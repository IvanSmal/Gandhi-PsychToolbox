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
        activestatetime=[]
        activestatename = 'null';
        targettime


        % trialtypes logic table
        ttypeslogic
        failcounter

        %collision stuff
        coltimer=0

        %eccentricity gain and target trails
        eccentricity_gain;
        trailing_window_time;

        %communicate with graphics
        senttimestamp=0;
        graphicsport;
        graphicssent=0
        cachedout = 'default'
        graphicscommandbuffer=''; %graphics buffer. move to private later
        lastcommand = 1; %move to private later
        holdbuffer = 0;
        readyforflip=1;
        commandID=0;
        lastsenttime=0;

        %shared-memory scene channel (replaces the UDP command stream).
        %The state machine overwrites a fixed binary slot; GraphicsHandler
        %reads the newest complete scene at its own refresh rate. Writer
        %never blocks on the renderer, so the two rates are independent.
        sceneMap;            % memmapfile handle, writable
        cmdList;             % commands accumulated for the frame being built
        sceneSeq = 0;        % monotonically increasing sequence number


        sceneSetEye = 0;     % one-shot: tell graphics to reload eye calibration

        %command timing log. Every published frame gets an ID (sceneSeq) and
        %a generation timestamp; the renderer records which IDs actually made
        %it to the screen. Joining the two on ID gives the true
        %generation-to-display latency for the commands that were displayed.
        %Preallocated and index-tracked: this runs in the 1 kHz loop.
        cmdLogId   = zeros(1,20000);
        cmdLogTime = zeros(1,20000);
        cmdLogN    = 0;
            
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

