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
%   eye/cursor with Mouse Mode instead), no digital events and no spikes.

    if ~isfile(demoFlagPath())
        error('xippmex:notInstalled', ...
            ['The real xippmex (Trellis MEX) is not on the path and demo mode ' ...
             'is not enabled. Connect Trellis, or launch in demo mode.']);
    end

    persistent t0
    if isempty(t0), t0 = now*86400; end %#ok<TNOW1>
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
            if strcmp(typ,'analog')
                varargout{1} = [10241 10242 10243 10244];   % eyeX, eyeY, spare, photodiode
            else
                varargout{1} = [];                          % no micro/stim electrodes in demo
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
            elecs = []; if nargin >= 2, elecs = varargin{2}; end
            n = numel(elecs);
            varargout{1} = zeros(1,n);
            if nargout >= 2, varargout{2} = repmat({zeros(1,0)},1,n); end
            if nargout >= 3, varargout{3} = repmat({[]},1,n); end
            if nargout >= 4, varargout{4} = repmat({[]},1,n); end

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
