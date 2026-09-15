classdef TrellisScope < handle
%TRELLISSCOPE Real-time, state-aligned scope for Trellis channels.
%
%   A separate window that plots 1-5 selected channels (neural activity or
%   eye X/Y), aligned on a chosen state (t=0 at its onset) and overlaid across
%   the last N trials over a user-set [-pre, +post] ms window.
%
%   Overlay is BY STATE, not by task: every trial whose task contains the
%   selected state is captured and drawn, coloured by task type (one colour
%   per task, shown in a legend). A trial whose task never enters that state
%   simply produces no window and is ignored -- so interleaved tasks that
%   share a state (e.g. several tasks that all have a "hold" state) overlay
%   together, and a task without it is skipped automatically.
%
%   Design notes
%   ------------
%   * Driven by a TIMER, not a while-loop, so the window stays responsive.
%     Line objects are created once and only their XData/YData/Color are
%     updated -- never plot()/cla in the loop -- with drawnow limitrate. This
%     is what keeps a MATLAB live plot smooth.
%   * The data source is pluggable. Phase 0 uses a synthetic generator so the
%     whole thing runs without Trellis. Phase 1 swaps in xippmex ('cont' for
%     channels, 'digin' for the state/trial markers MonkeyHost stamps on the
%     NIP). The acquire*/listChannels methods are the only pluggable seam.
%
%   Usage:  TrellisScope            % synthetic source (demo)
%           TrellisScope('sim',0)   % (Phase 1) real xippmex source

    properties
        fig                 % uifigure
        chAxes = gobjects(0)% one axes per selected channel (stacked)
        traceLines          % cell{nCh} of line handles, one per held trial slot
        liveLines           % line handles for the trial currently being captured

        % controls
        chDropdowns         % up to 5 channel selectors
        alignDrop           % alignment-state dropdown
        preField; postField % window pre/post in ms
        holdField           % how many trials to overlay (1-50)
        startBtn; statusLbl; trialLbl

        % configuration (read from controls when a run starts)
        channels = {}
        alignState = ''
        preMs = 200
        postMs = 500
        nHold = 10

        % data source
        sim = true
        fs = 1000
        chanList = {}

        % rolling capture state
        tmr
        running = false
        buf; bufT; bufFill = 0; bufN
        lastAcqT = 0
        curTrialName = ''
        seenStates = {}
        pending
        held
        simState
        dbgTicks = 0

        % colour-by-task
        typeColors          % containers.Map: task name -> RGB
        proxyLines          % containers.Map: task name -> legend proxy (top axes)
        palette

        % xippmex source
        chanMap             % containers.Map: friendly name -> struct(elec,type,unit)
        inited = false
        eyeCal              % struct: xgain,xoffset,ygain,yoffset
        lastNipTick = []    % NIP tick of the last appended sample (dedup)
        nPull = 300         % samples to pull per tick (100 ms of history at 1 kHz)
        metaMap             % shared-memory slot: current trial name from MonkeyHost
        stateOnsetMap       % shared-memory slot: state onsets (name + NIP tick) from setstate
        lastOnsetSeq = 0    % highest state-onset seq already emitted
        lastTrialName = ''  % last trial name read from the slot

        % spike raster (#5)
        chanKind            % cell{nCh}: 'cont' (line) or 'spike' (raster)
        spikeAccum          % containers.Map: channel name -> vector of recent spike times (source clock, s)

        % other-state markers (#3) and controls (#2,#4)
        stateHist           % struct(name,t): recent state onsets, to mark the non-aligned ones
        markLines           % cell{nCh}: pool of vertical lines for other-state onsets
        markColors          % containers.Map: state name -> RGB
        markPool = 80       % vertical-line pool size per axes
        refreshBtn; yAutoBox; yMinField; yMaxField
    end

    methods
        function app = TrellisScope(varargin)
            p = inputParser; p.addParameter('sim', true); p.parse(varargin{:});
            app.sim = logical(p.Results.sim);
            app.palette = lines(12);
            app.typeColors = containers.Map('KeyType','char','ValueType','any');
            app.proxyLines = containers.Map('KeyType','char','ValueType','any');
            app.markColors = containers.Map('KeyType','char','ValueType','any');
            app.chanList = app.listChannels();
            app.bufN = 20000;                    % 20 s of history at 1 kHz
            app.resetBuffers();
            app.buildUI();
        end

        % ---------------------------------------------------------------- UI
        function buildUI(app)
            app.fig = uifigure('Name','Trellis Scope', 'Position',[200 150 1000 640]);
            g = uigridlayout(app.fig, [1 2]);
            g.ColumnWidth = {240, '1x'}; g.RowHeight = {'1x'};

            cp = uipanel(g, 'Title','Scope'); cp.Layout.Column = 1;
            cg = uigridlayout(cp, [20 2]);
            cg.RowHeight = repmat({26}, 1, 20); cg.ColumnWidth = {90, '1x'};

            hL = uilabel(cg,'Text','Channels (1-5):','FontWeight','bold'); hL.Layout.Column = [1 2];
            app.chDropdowns = gobjects(1,5);
            for i = 1:5
                app.chDropdowns(i) = uidropdown(cg,'Items',[{'(none)'} app.chanList],'Value','(none)');
                app.chDropdowns(i).Layout.Column = [1 2];
            end
            if numel(app.chanList) >= 1, app.chDropdowns(1).Value = app.chanList{1}; end
            if numel(app.chanList) >= 2, app.chDropdowns(2).Value = app.chanList{2}; end

            hA = uilabel(cg,'Text','Align on state:','FontWeight','bold'); hA.Layout.Column = [1 2];
            app.alignDrop = uidropdown(cg,'Items',{'(waiting for trials)'},'Value','(waiting for trials)');
            app.alignDrop.Layout.Column = [1 2];

            uilabel(cg,'Text','Pre (ms):');
            app.preField = uieditfield(cg,'numeric','Value',app.preMs,'Limits',[0 60000]);
            uilabel(cg,'Text','Post (ms):');
            app.postField = uieditfield(cg,'numeric','Value',app.postMs,'Limits',[1 60000]);
            uilabel(cg,'Text','Hold trials:');
            app.holdField = uieditfield(cg,'numeric','Value',app.nHold,'Limits',[1 50],'RoundFractionalValues','on');

            % Y-axis controls (#4): auto by default; when off, apply [min max] to all plots
            app.yAutoBox = uicheckbox(cg,'Text','Y auto','Value',true, ...
                'ValueChangedFcn',@(s,~) app.onYAuto(s));
            app.yAutoBox.Layout.Column = [1 2];
            uilabel(cg,'Text','Y min:');
            app.yMinField = uieditfield(cg,'numeric','Value',-1,'Enable','off','ValueChangedFcn',@(~,~) app.applyYLimits());
            uilabel(cg,'Text','Y max:');
            app.yMaxField = uieditfield(cg,'numeric','Value', 1,'Enable','off','ValueChangedFcn',@(~,~) app.applyYLimits());

            app.startBtn = uibutton(cg,'state','Text','Start','ValueChangedFcn',@(s,~) app.onStartStop(s));
            app.startBtn.Layout.Column = [1 2];
            % Refresh (#2): apply control changes in one click (stop + start)
            app.refreshBtn = uibutton(cg,'push','Text','Refresh','ButtonPushedFcn',@(~,~) app.onRefresh());
            app.refreshBtn.Layout.Column = [1 2];
            app.trialLbl = uilabel(cg,'Text','trial: --'); app.trialLbl.Layout.Column = [1 2];
            app.statusLbl = uilabel(cg,'Text','idle','FontColor',[0.4 0.4 0.4]); app.statusLbl.Layout.Column = [1 2];

            pp = uipanel(g,'Title',''); pp.Layout.Column = 2;
            app.buildAxes(pp, {'(no channels)'});
        end

        function buildAxes(app, parent, chNames)
            delete(app.chAxes(isgraphics(app.chAxes)));
            remove(app.proxyLines, app.proxyLines.keys);   % proxies live on the old axes
            nCh = numel(chNames);
            pg = uigridlayout(parent, [nCh 1]);
            app.chAxes = gobjects(1,nCh); app.traceLines = cell(1,nCh);
            app.liveLines = gobjects(1,nCh); app.markLines = cell(1,nCh);
            for c = 1:nCh
                isSpk = numel(app.chanKind) >= c && strcmp(app.chanKind{c},'spike');
                ax = uiaxes(pg); grid(ax,'on'); hold(ax,'on');
                if isSpk, ylabel(ax, [chNames{c} ' (trials)']); else, ylabel(ax, chNames{c}); end
                if c == nCh, xlabel(ax,'time from alignment (ms)'); end
                xline(ax, 0, 'Color',[0 0 0 0.6], 'LineWidth', 1);
                % pool of vertical lines (xline spans the axes and never affects
                % auto-scale) for the OTHER (non-aligned) state onsets (#3)
                M = gobjects(1, app.markPool);
                for k = 1:app.markPool
                    M(k) = xline(ax, NaN, 'LineWidth', 0.5, 'Interpreter', 'none'); M(k).Visible = 'off';
                end
                app.markLines{c} = M;
                % one line per held trial: a signal (cont) or a row of ticks (spike)
                L = gobjects(1, app.nHold);
                for k = 1:app.nHold
                    if isSpk
                        L(k) = plot(ax, nan, nan, 'LineStyle','none','Marker','|','MarkerSize',6,'LineWidth',1);
                    else
                        L(k) = plot(ax, nan, nan, 'LineWidth', 1);   % coloured per task in redraw
                    end
                end
                app.traceLines{c} = L;
                if isSpk
                    app.liveLines(c) = plot(ax, nan, nan, 'LineStyle','none','Marker','|','MarkerSize',7,'LineWidth',1.5);
                    ylim(ax, [0.5 app.nHold+1.5]);   % top row (nHold+1) is the live capture
                else
                    app.liveLines(c) = plot(ax, nan, nan, 'LineWidth', 1.8);
                end
                try, enableDefaultInteractivity(ax); ax.Toolbar.Visible = 'on'; catch, end
                app.chAxes(c) = ax;
            end
        end

        % ------------------------------------------------------- start/stop
        function onStartStop(app, src)
            if src.Value, app.beginRun(); src.Text = 'Stop';
            else,         app.endRun();   src.Text = 'Start'; end
        end

        function beginRun(app)
            app.channels = {};
            for i = 1:5
                v = app.chDropdowns(i).Value;
                if ~strcmp(v,'(none)'), app.channels{end+1} = v; end %#ok<AGROW>
            end
            if isempty(app.channels)
                app.statusLbl.Text = 'pick at least one channel'; app.startBtn.Value = false; return
            end
            app.preMs = app.preField.Value; app.postMs = app.postField.Value;
            app.nHold = app.holdField.Value; app.alignState = app.alignDrop.Value;

            app.chanKind = cell(1, numel(app.channels));
            for c = 1:numel(app.channels)
                if app.isSpikeChan(app.channels{c}), app.chanKind{c} = 'spike'; else, app.chanKind{c} = 'cont'; end
            end
            app.spikeAccum = containers.Map('KeyType','char','ValueType','any');

            app.buildAxes(app.chAxes(1).Parent.Parent, app.channels);
            for c = 1:numel(app.chAxes), xlim(app.chAxes(c), [-app.preMs app.postMs]); end

            app.resetBuffers();
            app.held = struct('name',{},'t',{},'y',{},'marks',{},'spk',{});
            app.pending = struct('name',{},'t0',{},'endT',{});
            app.stateHist = struct('name',{},'t',{});
            app.stateOnsetMap = []; app.lastOnsetSeq = 0;
            try   % skip onsets already in the ring so only NEW ones show
                m0 = sceneOpen(false, stateOnsetPath());
                [f0,ok0] = sceneRead(m0);
                if ok0 && isstruct(f0) && isfield(f0,'onsets') && ~isempty(f0.onsets)
                    app.lastOnsetSeq = max([f0.onsets.seq]);
                end
            catch
            end
            app.typeColors = containers.Map('KeyType','char','ValueType','any');
            app.lastAcqT = app.sourceNow();
            if app.sim, app.initSim();
            else,       app.xippmexInit(); app.lastNipTick = []; xippmex('digin'); end

            app.running = true;
            app.statusLbl.Text = 'running'; app.statusLbl.FontColor = [0 0.5 0];
            app.tmr = timer('ExecutionMode','fixedSpacing','Period',0.03,'BusyMode','drop', ...
                'TimerFcn',@(~,~) app.tick());
            start(app.tmr);
        end

        function endRun(app)
            app.running = false;
            try, stop(app.tmr); delete(app.tmr); catch, end
            app.statusLbl.Text = 'stopped'; app.statusLbl.FontColor = [0.4 0.4 0.4];
        end

        % ------------------------------------------------------- main tick
        function tick(app)
            if ~app.running || ~isvalid(app.fig), return; end
            app.dbgTicks = app.dbgTicks + 1;
            try
                [chunkT, chunkY, events] = app.acquire();
                app.pushSamples(chunkT, chunkY);
                app.handleEvents(events);
                app.completePending();
                app.redraw();
            catch e
                app.statusLbl.Text = ['error: ' e.message]; app.statusLbl.FontColor = [0.8 0 0];
            end
        end

        function pushSamples(app, tvec, ymat)
            n = numel(tvec); if n == 0, return; end
            idx = mod(app.bufFill + (0:n-1), app.bufN) + 1;
            app.bufT(idx) = tvec;
            for c = 1:numel(app.channels), app.buf(c).y(idx) = ymat(c,:); end
            app.bufFill = app.bufFill + n; app.lastAcqT = tvec(end);
        end

        function handleEvents(app, events)
            for i = 1:numel(events)
                ev = events(i);
                switch ev.kind
                    case 'trial'
                        app.curTrialName = ev.name; app.trialLbl.Text = ['trial: ' ev.name];
                    case 'state'
                        if ~any(strcmp(app.seenStates, ev.name))
                            app.seenStates{end+1} = ev.name; app.refreshStateDropdown(); %#ok<AGROW>
                        end
                        app.stateHist(end+1) = struct('name',ev.name,'t',ev.t);  %#ok<AGROW>
                        if numel(app.stateHist) > 500, app.stateHist = app.stateHist(end-499:end); end
                        if strcmp(ev.name, app.alignState)
                            w.name = app.curTrialName; w.t0 = ev.t; w.endT = ev.t + app.postMs/1000;
                            app.pending(end+1) = w; %#ok<AGROW>
                        end
                end
            end
        end

        function completePending(app)
            keep = true(1, numel(app.pending));
            for i = 1:numel(app.pending)
                w = app.pending(i);
                if app.lastAcqT >= w.endT
                    [t, y] = app.extractWindow(w.t0);
                    spk = cell(1, numel(app.channels));
                    for c = 1:numel(app.channels)
                        if strcmp(app.chanKind{c},'spike'), spk{c} = app.extractSpikes(w.t0, c); end
                    end
                    if ~isempty(t)
                        rec.name = w.name; rec.t = t; rec.y = y; rec.spk = spk;
                        rec.marks = app.windowMarks(w.t0);   % other-state onsets in this window
                        app.held(end+1) = rec; %#ok<AGROW>
                    end
                    keep(i) = false;
                end
            end
            app.pending = app.pending(keep);
            % keep the last nHold captured windows, of ANY task type
            if numel(app.held) > app.nHold, app.held = app.held(end-app.nHold+1:end); end
        end

        function [t, y] = extractWindow(app, t0)
            t = []; y = [];
            if app.bufFill == 0, return; end
            n = min(app.bufFill, app.bufN);
            idx = mod((app.bufFill-n) + (0:n-1), app.bufN) + 1;
            tt = app.bufT(idx);
            sel = tt >= t0 - app.preMs/1000 & tt <= t0 + app.postMs/1000;
            if ~any(sel), return; end
            t = (tt(sel) - t0) * 1000;
            y = zeros(numel(app.channels), numel(t));
            for c = 1:numel(app.channels), yc = app.buf(c).y(idx); y(c,:) = yc(sel); end
        end

        function accumSpikes(app, name, sp)
            % Append spike times (source clock, s) for a spike channel to the
            % rolling accumulator, trimmed to the last 60 s to bound memory.
            if ~isKey(app.spikeAccum, name), app.spikeAccum(name) = zeros(1,0); end
            tv = [app.spikeAccum(name), sp(:)'];
            cutoff = app.sourceNow() - 60;
            tv = tv(tv >= cutoff);
            app.spikeAccum(name) = tv;
        end

        function sp = extractSpikes(app, t0, c)
            % Spike times within [-pre, +post] of t0, relative to t0, in ms.
            sp = zeros(1,0);
            nm = app.channels{c};
            if ~isKey(app.spikeAccum, nm), return; end
            tv = app.spikeAccum(nm);
            sel = tv >= t0 - app.preMs/1000 & tv <= t0 + app.postMs/1000;
            sp = (tv(sel) - t0) * 1000;
        end

        % --------------------------------------------------------- drawing
        function redraw(app)
            nCh = numel(app.channels);
            for c = 1:nCh
                L = app.traceLines{c}; nh = numel(app.held);
                isSpk = strcmp(app.chanKind{c},'spike');
                for k = 1:app.nHold
                    if k <= nh
                        rec = app.held(k);
                        if isSpk
                            sp = rec.spk{c};
                            set(L(k),'XData',sp,'YData',k*ones(1,numel(sp)),'Color',app.colorForType(rec.name));
                        else
                            set(L(k),'XData',rec.t,'YData',rec.y(c,:),'Color',app.colorForType(rec.name));
                        end
                    else
                        set(L(k),'XData',nan,'YData',nan);
                    end
                end
                if ~isempty(app.pending)
                    if isSpk
                        sp = app.extractSpikes(app.pending(end).t0, c);
                        set(app.liveLines(c),'XData',sp,'YData',(app.nHold+1)*ones(1,numel(sp)), ...
                            'Color',app.colorForType(app.pending(end).name));
                    else
                        [t, y] = app.extractWindow(app.pending(end).t0);
                        if ~isempty(t)
                            set(app.liveLines(c),'XData',t,'YData',y(c,:),'Color',app.colorForType(app.pending(end).name));
                        end
                    end
                else
                    set(app.liveLines(c),'XData',nan,'YData',nan);
                end

                % other-state markers (#3): every held window's non-aligned
                % onsets, coloured per state; only the newest window is labelled
                M = app.markLines{c}; mi = 0; nh = numel(app.held);
                for k = 1:nh
                    mk = app.held(k).marks;
                    for j = 1:numel(mk)
                        mi = mi + 1; if mi > app.markPool, break; end
                        M(mi).Value = mk(j).rel; M(mi).Color = app.colorForMark(mk(j).name);
                        M(mi).Visible = 'on';
                        if k == nh && c == 1, M(mi).Label = mk(j).name; else, M(mi).Label = ''; end
                    end
                    if mi > app.markPool, break; end
                end
                for k = mi+1:app.markPool, M(k).Visible = 'off'; M(k).Label = ''; end
            end
            if app.yAutoBox.Value
                for c = 1:nCh
                    if ~strcmp(app.chanKind{c},'spike') && isgraphics(app.chAxes(c))
                        app.chAxes(c).YLimMode = 'auto';   % spike axes keep their row-based ylim
                    end
                end
            end
            drawnow limitrate
        end

        function marks = windowMarks(app, t0)
            marks = struct('name',{},'rel',{});
            if isempty(app.stateHist), return; end
            tt = [app.stateHist.t];
            sel = tt >= t0-app.preMs/1000 & tt <= t0+app.postMs/1000 & abs(tt-t0) > 0.001;
            for j = find(sel)
                marks(end+1) = struct('name',app.stateHist(j).name, ...
                    'rel',(app.stateHist(j).t-t0)*1000); %#ok<AGROW>
            end
        end

        function col = colorForMark(app, name)
            if ~isKey(app.markColors, name)
                idx = app.markColors.Count + 1;
                base = app.palette(mod(idx-1,size(app.palette,1))+1,:);
                app.markColors(name) = 0.45*base + 0.55*[1 1 1];   % muted
            end
            col = app.markColors(name);
        end

        function onRefresh(app)
            if app.running, app.endRun(); end
            app.startBtn.Value = true; app.startBtn.Text = 'Stop';
            app.beginRun();
        end

        function onYAuto(app, s)
            man = ~s.Value;
            app.yMinField.Enable = man; app.yMaxField.Enable = man;
            if man && ~isempty(app.chAxes) && isgraphics(app.chAxes(1))
                yl = app.chAxes(1).YLim; app.yMinField.Value = yl(1); app.yMaxField.Value = yl(2);
                app.applyYLimits();
            end
        end

        function applyYLimits(app)
            if app.yAutoBox.Value, return; end
            for c = 1:numel(app.chAxes)
                if isgraphics(app.chAxes(c)) && ~(numel(app.chanKind)>=c && strcmp(app.chanKind{c},'spike'))
                    app.chAxes(c).YLim = [app.yMinField.Value app.yMaxField.Value];   % skip raster axes
                end
            end
        end

        function col = colorForType(app, name)
            if isempty(name), name = '(unnamed)'; end
            if ~isKey(app.typeColors, name)
                idx = app.typeColors.Count + 1;
                col = app.palette(mod(idx-1, size(app.palette,1)) + 1, :);
                app.typeColors(name) = col;
                if ~isempty(app.chAxes) && isgraphics(app.chAxes(1))
                    app.proxyLines(name) = plot(app.chAxes(1), nan, nan, 'Color', col, 'LineWidth', 2);
                    ph = app.proxyLines.values; ph = [ph{:}];
                    legend(app.chAxes(1), ph, app.proxyLines.keys, 'Location','northeast', 'AutoUpdate','off', 'Interpreter','none');
                end
            end
            col = app.typeColors(name);
        end

        function refreshStateDropdown(app)
            cur = app.alignDrop.Value;
            app.alignDrop.Items = app.seenStates;
            if any(strcmp(app.seenStates, cur)), app.alignDrop.Value = cur;
            elseif ~isempty(app.seenStates) && (isempty(app.alignState) || strcmp(cur,'(waiting for trials)'))
                app.alignDrop.Value = app.seenStates{1}; app.alignState = app.seenStates{1};
            end
        end

        function resetBuffers(app)
            nCh = max(1, numel(app.channels));
            app.bufT = zeros(1, app.bufN);
            app.buf = struct('y', repmat({zeros(1, app.bufN)}, 1, nCh));
            app.bufFill = 0;
        end

        % =============================================== DATA SOURCE (pluggable)
        function names = listChannels(app)
            if app.sim, names = {'eyeX','eyeY','neural01','neural02','spikes01','spikes02'};
            else,       names = app.xippmexChannels(); end
        end

        function tf = isSpikeChan(app, name)
            if app.sim, tf = startsWith(name,'spikes');
            elseif isKey(app.chanMap, name), tf = strcmp(app.chanMap(name).kind, 'spike');
            else, tf = false; end
        end
        function t = sourceNow(app)
            if app.sim, t = now*86400; else, t = app.xippmexNow(); end %#ok<TNOW1>
        end
        function [tvec, ymat, events] = acquire(app)
            if app.sim, [tvec, ymat, events] = app.acquireSim();
            else,       [tvec, ymat, events] = app.acquireXippmex(); end
        end

        function initSim(app)
            % Interleave several tasks. Ex_A and Ex_B both have 'target';
            % Ex_C does not -- so aligning on 'target' overlays A and B (two
            % colours) and ignores C.
            tasks = { ...
                struct('name','Ex_A','states',{{'fixate','hold','target','reward'}},'offsets',[0 0.3 0.7 1.4],'trialLen',2.0), ...
                struct('name','Ex_B','states',{{'fixate','target','reward'}},        'offsets',[0 0.5 1.2],    'trialLen',1.8), ...
                struct('name','Ex_C','states',{{'fixate','hold','reward'}},          'offsets',[0 0.4 1.0],    'trialLen',1.6)};
            app.simState = struct('trialStart',app.lastAcqT,'stateIdx',0,'tasks',{tasks}, ...
                'cur',tasks{1},'name',tasks{1}.name);
        end

        function [tvec, ymat, events] = acquireSim(app)
            s = app.simState; tnow = app.sourceNow(); dt = 1/app.fs;
            tvec = (app.lastAcqT + dt) : dt : tnow; if isempty(tvec), tvec = zeros(1,0); end
            nCh = numel(app.channels); ymat = zeros(nCh, numel(tvec));
            inBurst = false(1, numel(tvec));
            events = struct('kind',{},'name',{},'t',{});
            for k = 1:numel(tvec)
                tt = tvec(k); trialT = tt - s.trialStart;
                if trialT >= s.cur.trialLen
                    s.cur = s.tasks{randi(numel(s.tasks))}; s.name = s.cur.name;
                    s.trialStart = tt; s.stateIdx = 0; trialT = 0;
                    events(end+1) = struct('kind','trial','name',s.name,'t',tt); %#ok<AGROW>
                end
                ni = find(trialT >= s.cur.offsets, 1, 'last');
                if ~isempty(ni) && ni > s.stateIdx
                    s.stateIdx = ni;
                    events(end+1) = struct('kind','state','name',s.cur.states{ni},'t',tt); %#ok<AGROW>
                end
                hasTarget = any(strcmp(s.cur.states,'target'));
                tOnset = 0; if hasTarget, tOnset = s.cur.offsets(strcmp(s.cur.states,'target')); end
                inBurst(k) = hasTarget && trialT > tOnset && trialT < tOnset+0.15;
                for c = 1:nCh
                    if ~strcmp(app.chanKind{c},'spike')
                        ymat(c,k) = app.simChannel(app.channels{c}, tt, trialT, hasTarget, tOnset);
                    end
                end
            end
            app.simState = s;
            % synthetic spikes for spike channels: baseline + a burst after target
            for c = 1:nCh
                if strcmp(app.chanKind{c},'spike') && ~isempty(tvec)
                    rate = 20 + 250*inBurst;                 % Hz
                    sp = tvec(rand(1,numel(tvec)) < rate*dt);
                    app.accumSpikes(app.channels{c}, sp);
                end
            end
        end

        function v = simChannel(~, name, tt, trialT, hasTarget, tOnset)
            switch name
                case 'eyeX', v = 5*(hasTarget && trialT > tOnset) + 0.3*randn;
                case 'eyeY', v = -3*(hasTarget && trialT > tOnset) + 0.3*randn;
                otherwise
                    v = 0.2*randn;
                    if hasTarget && trialT > tOnset && trialT < tOnset+0.15
                        v = v + 2*sin(2*pi*80*tt);
                    end
            end
        end

        % ------------------------------------------------- xippmex source
        function names = xippmexChannels(app)
            % Build the selectable channel list from what Trellis reports, and
            % remember how to read each one (electrode, stream type, unit).
            app.xippmexInit();
            app.chanMap = containers.Map('KeyType','char','ValueType','any');
            names = {};
            an = xippmex('elec','analog');
            friendly = containers.Map({10241,10242,10244}, {'eyeX','eyeY','photodiode'});
            for e = an
                if isKey(friendly, e), nm = friendly(e); else, nm = sprintf('analog %d', e); end
                unit = 'adc'; if any(e == [10241 10242]), unit = 'deg'; end
                app.chanMap(nm) = struct('elec',e,'type','1ksps','unit',unit,'kind','cont');
                names{end+1} = nm; %#ok<AGROW>
            end
            micro = xippmex('elec','micro');
            for e = micro
                nm = sprintf('lfp %d', e);
                app.chanMap(nm) = struct('elec',e,'type','lfp','unit','uV','kind','cont');
                names{end+1} = nm; %#ok<AGROW>
            end
            % one raster channel per micro electrode (sorted units combined)
            for e = micro
                nm = sprintf('spk %d', e);
                app.chanMap(nm) = struct('elec',e,'type','spike','unit','','kind','spike');
                names{end+1} = nm; %#ok<AGROW>
            end
        end

        function xippmexInit(app)
            if app.inited, return; end
            xippmex;                                        % connect to the NIP (idempotent)
            try
                si = rigIni('state');
                app.eyeCal = struct( ...
                    'xgain',  si.GetValues('eye calibration','xgain'), ...
                    'xoffset',si.GetValues('eye calibration','xoffset'), ...
                    'ygain',  si.GetValues('eye calibration','ygain'), ...
                    'yoffset',si.GetValues('eye calibration','yoffset'));
            catch
                app.eyeCal = struct('xgain',1,'xoffset',0,'ygain',1,'yoffset',0);
            end
            xippmex('digin');                               % clear the digital buffer
            app.lastNipTick = [];
            try, app.metaMap = sceneOpen(false, scopeMetaPath()); catch, app.metaMap = []; end
            app.inited = true;
        end

        function t = xippmexNow(~), t = double(xippmex('time'))/30000; end

        function [tvec, ymat, events] = acquireXippmex(app)
            N = app.nPull; nCh = numel(app.channels);
            % group selected channels by stream type; always read the eye pair
            % if any eye channel is shown (pix2deg needs both x and y)
            need1k = []; needLfp = []; needSpk = [];
            for c = 1:nCh
                m = app.chanMap(app.channels{c});
                if strcmp(m.kind,'spike'),      needSpk(end+1) = m.elec; %#ok<AGROW>
                elseif strcmp(m.type,'lfp'),    needLfp(end+1) = m.elec; %#ok<AGROW>
                else,                           need1k(end+1) = m.elec; %#ok<AGROW>
                end
            end
            wantEye = any(ismember(app.channels,{'eyeX','eyeY'}));
            if wantEye, need1k = unique([need1k 10241 10242]); end

            refTick = []; d1 = []; e1 = unique(need1k); dL = []; eL = unique(needLfp);
            if ~isempty(e1)
                [d1, ts1] = xippmex('cont', e1, N, '1ksps'); refTick = double(ts1);
            end
            if ~isempty(eL)
                [dL, tsL] = xippmex('cont', eL, N, 'lfp');
                if isempty(refTick), refTick = double(tsL); end
            end
            if isempty(refTick) || refTick == 0
                refTick = double(xippmex('time')) - (N-1)*30;   % approximate: batch ends ~now
            end

            ticks = refTick + (0:N-1)*30;                    % NIP tick per sample (1 kHz -> 30 ticks)
            keep = true(1,N);
            if ~isempty(app.lastNipTick), keep = ticks > app.lastNipTick; end
            if ~any(keep)
                tvec = zeros(1,0); ymat = zeros(nCh,0); events = app.readDigin(); return
            end
            app.lastNipTick = ticks(end);
            tvec = ticks(keep) / 30000;

            % eye pair -> degrees, once (pix2deg with no screenparams reads the ini)
            if wantEye && ~isempty(d1)
                xr = d1(e1==10241, :); yr = d1(e1==10242, :);
                xpix = xr*app.eyeCal.xgain + app.eyeCal.xoffset;
                ypix = yr*app.eyeCal.ygain + app.eyeCal.yoffset;
                try, deg = pix2deg([xpix' ypix'],'cart'); catch, deg = [xpix' ypix']; end
            end

            ymat = zeros(nCh, sum(keep));
            for c = 1:nCh
                m = app.chanMap(app.channels{c}); nm = app.channels{c};
                if strcmp(m.kind,'spike'), continue; end   % raster channels carry no continuous row
                switch nm
                    case 'eyeX', row = deg(:,1)';
                    case 'eyeY', row = deg(:,2)';
                    otherwise
                        if strcmp(m.type,'lfp'), row = dL(eL==m.elec, :);
                        else,                     row = d1(e1==m.elec, :); end
                end
                ymat(c,:) = row(keep);
            end

            % drain new spikes from Trellis into the accumulator (source clock, s)
            se = unique(needSpk);
            if ~isempty(se)
                [~, tss] = xippmex('spike', se, zeros(1,numel(se)));
                for c = 1:nCh
                    m = app.chanMap(app.channels{c});
                    if ~strcmp(m.kind,'spike'), continue; end
                    ii = find(se == m.elec, 1);
                    if ~isempty(ii) && ~isempty(tss{ii})
                        app.accumSpikes(app.channels{c}, double(tss{ii}(:)')/30000);
                    end
                end
            end
            events = app.readDigin();
            % current trial name from MonkeyHost -> a 'trial' event when it changes
            tn = app.readTrialName();
            if ~isempty(tn) && ~strcmp(tn, app.lastTrialName)
                app.lastTrialName = tn;
                events = [struct('kind','trial','name',tn,'t',app.xippmexNow()), events];
            end
        end

        function tn = readTrialName(app)
            tn = '';
            if isempty(app.metaMap), return; end
            try
                [m, ok] = sceneRead(app.metaMap);
                if ok && isfield(m,'trialName'), tn = m.trialName; end
            catch
            end
        end

        function events = readDigin(app)
            % State onsets from the shared state-onset slot: setstate publishes
            % each transition (name + NIP tick) there, so onsets are marked with
            % PRECISE NIP timestamps (the same clock as the eye/spike data) and
            % none are missed between polls (a 32-deep ring). Independent of the
            % digout event codes, which timestamp states in the neural recording.
            events = struct('kind',{},'name',{},'t',{});
            try
                if isempty(app.stateOnsetMap)
                    app.stateOnsetMap = sceneOpen(false, stateOnsetPath());
                end
                [fr, ok] = sceneRead(app.stateOnsetMap);
                if ~ok || ~isstruct(fr) || ~isfield(fr,'onsets'), return; end
                ons = fr.onsets;
                for i = 1:numel(ons)
                    if ons(i).seq > app.lastOnsetSeq
                        app.lastOnsetSeq = ons(i).seq;
                        events(end+1) = struct('kind','state','name',char(ons(i).name), ...
                            't', double(ons(i).tick)/30000); %#ok<AGROW>
                    end
                end
            catch
                app.stateOnsetMap = [];
            end
        end
    end
end
