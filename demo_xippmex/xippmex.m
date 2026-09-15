function varargout = xippmex(varargin)
%XIPPMEX (DEMO/MOCK) Stand-in for the real xippmex MEX so the app runs without
%   Trellis. This file lives in the demo folder and normally loses to the real
%   xippmex MEX (MEX beats .m); it is reached only after enableDemoXippmex has
%   removed the real xippmex from the path. As a safety net it refuses to run
%   unless demo mode is actually enabled (the flag file exists), so it can never
%   silently masquerade as a connected system.
%
%   It returns valid-shaped, harmless data: "connected", a monotonic NIP clock
%   from the wall clock, a few fake analog channels, flat continuous data (drive
%   eye/cursor with Mouse Mode instead), no digital events, and high-rate
%   synthetic spikes on 32 fake micro electrodes so the raster / Spike Scope look
%   alive (deep-structure rates, 200-1000 spikes/s).

    if ~isfile(demoFlagPath())
        error('xippmex:notInstalled', ...
            ['The real xippmex (Trellis MEX) is not on the path and demo mode ' ...
             'is not enabled. Connect Trellis, or launch in demo mode.']);
    end

    persistent t0
    if isempty(t0), t0 = floor(now)*86400; end %#ok<TNOW1>  % midnight epoch: all demo clients share one NIP clock
    nowTick = @() uint32(round((now*86400 - t0)*30000));   % 30 kHz NIP ticks

    cmd = '';
    if nargin >= 1 && (ischar(varargin{1}) || isstring(varargin{1})), cmd = char(varargin{1}); end
    [varargout{1:max(nargout,1)}] = deal([]);

    switch lower(cmd)
        case ''                                   % bare xippmex() -> connected
            varargout{1} = 1;

        case 'time'
            varargout{1} = nowTick();

        case 'elec'
            typ = 'analog'; if nargin >= 2, typ = lower(char(varargin{2})); end
            switch typ
                case 'analog'
                    varargout{1} = [10241 10242 10243 10244];   % eyeX, eyeY, spare, photodiode
                case 'micro'
                    varargout{1} = demoMicroElecs();            % fake spike/LFP electrodes
                otherwise
                    varargout{1} = [];                          % no stim/other electrodes in demo
            end

        case 'cont'
            chans = []; N = 1;
            if nargin >= 2, chans = varargin{2}; end
            if nargin >= 3, N = varargin{3}; end
            nCh = numel(chans);
            % A sine wave per channel (distinct frequency/phase), continuous
            % across calls via the wall-clock time base, so the eye/analog
            % signal moves. Amplitude AMP is in raw units -- adjust if the eye
            % calibration maps it off-screen.
            fs = 1000;                                       % 1ksps / lfp ~ 1 kHz
            AMP = 500;
            tg = now*86400 - t0;                             %#ok<TNOW1>
            tsamp = tg + (0:N-1)/fs;                         % sample times (s)
            data = zeros(nCh, N);
            for k = 1:nCh
                f = 0.3 + 0.1*k;                             % Hz, distinct per channel
                data(k,:) = AMP * sin(2*pi*f*tsamp + k);     % per-channel phase
            end
            varargout{1} = data;
            if nargout >= 2
                varargout{2} = double(nowTick()) - (N-1)*30;  % first sample's tick (scalar)
            end

        case 'digin'
            varargout{1} = 0;                               % count
            if nargout >= 2, varargout{2} = []; end          % timestamps
            if nargout >= 3, varargout{3} = []; end          % events

        case 'spike'
            % Synthetic spikes since the last call: a homogeneous Poisson train
            % per electrode at that electrode's (stable) deep-structure rate.
            elecs = []; if nargin >= 2, elecs = varargin{2}; end
            [cnt, tss, wfs, uns] = demoSpikes(elecs, nowTick());
            varargout{1} = cnt;                              % count per electrode
            if nargout >= 2, varargout{2} = tss; end          % NIP-tick timestamps (cell)
            if nargout >= 3, varargout{3} = wfs; end          % 52-sample waveforms (cell)
            if nargout >= 4, varargout{4} = uns; end          % unit labels 0-4 (cell)

        case 'trial'
            % Simulate Trellis file control. 'recording' advances a trial
            % counter so demo trials get unique numbers (real recording would);
            % it stays under the app's 50000 "looks weird" guard. No file is
            % actually written -- there is no hardware in demo mode.
            persistent trialnum
            if isempty(trialnum), trialnum = 0; end
            sub = ''; if nargin >= 2, sub = lower(char(varargin{2})); end
            if strcmp(sub, 'recording')
                trialnum = trialnum + 1;
                varargout{1} = struct('incr_num', trialnum, 'status', 'recording');
            else
                varargout{1} = struct('incr_num', trialnum, 'status', 'stopped');
            end

        otherwise                                           % digout/close/stim/etc: no-op
            if nargout >= 1, varargout{1} = []; end
    end
end

% ------------------------------------------------------------------------
function e = demoMicroElecs()
%DEMOMICROELECS Fake micro (spike/LFP) electrode ids for the demo.
    e = 1:32;
end

function [cnt, tss, wfs, uns] = demoSpikes(elecs, nowT)
%DEMOSPIKES Poisson spike trains since the last call, one per electrode.
%   Each electrode fires at a stable rate in [200,1000] Hz (deep-structure
%   range). Times are generated as a homogeneous Poisson process via
%   exponential inter-spike intervals (no Statistics Toolbox needed), returned
%   as NIP 30-kHz ticks. A per-electrode "last read" tick is kept so each call
%   returns only new spikes, mirroring the real buffer-drain behaviour; the
%   look-back is capped at 0.5 s and 1024 spikes (the real circular buffer).
    persistent lastTick rate
    if isempty(lastTick), lastTick = containers.Map('KeyType','double','ValueType','double'); end
    if isempty(rate),     rate     = containers.Map('KeyType','double','ValueType','double'); end
    FS = 30000; MAXWIN = 0.5*FS; MAXSPK = 1024;

    elecs = double(elecs(:)'); n = numel(elecs);
    cnt = zeros(1,n);
    tss = repmat({zeros(1,0,'uint32')}, 1, n);
    wfs = repmat({zeros(0,52)}, 1, n);
    uns = repmat({zeros(0,1)}, 1, n);
    nowT = double(nowT);

    for i = 1:n
        e = elecs(i);
        if ~isKey(rate, e)
            rate(e) = 200 + 800*mod(sin(e*12.9898)*43758.5453, 1);   % 200-1000 Hz, stable per electrode
        end
        if ~isKey(lastTick, e), lastTick(e) = nowT - MAXWIN; end
        t0 = lastTick(e);
        if nowT - t0 > MAXWIN, t0 = nowT - MAXWIN; end               % cap look-back

        meanISI = FS / rate(e);                                      % mean ticks between spikes
        ticks = zeros(1, MAXSPK); k = 0; t = t0;
        while true
            t = t - meanISI*log(rand);                              % exponential inter-spike interval
            if t >= nowT || k >= MAXSPK, break; end
            k = k + 1; ticks(k) = t;
        end
        lastTick(e) = nowT;

        if k > 0
            cnt(i) = k;
            tss{i} = uint32(round(ticks(1:k)));
            wfs{i} = demoWave(k);
            uns{i} = demoUnits(k);
        end
    end
end

function w = demoWave(k)
%DEMOWAVE k fake 52-sample spike waveforms (uV): a biphasic template + noise.
    tt = linspace(-1, 1, 52);
    tmpl = -exp(-((tt+0.10)/0.15).^2) + 0.4*exp(-((tt-0.20)/0.25).^2);
    tmpl = tmpl / max(abs(tmpl)) * -80;    % ~ -80 uV trough
    w = repmat(tmpl, k, 1) + 8*randn(k, 52);
end

function u = demoUnits(k)
%DEMOUNITS k unit labels: mostly sorted unit 1, some unsorted (0) / a second (2).
    u = ones(k, 1);
    r = rand(k, 1);
    u(r < 0.20) = 0;
    u(r > 0.90) = 2;
end
