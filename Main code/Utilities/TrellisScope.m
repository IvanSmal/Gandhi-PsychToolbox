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
    end

    methods
        function app = TrellisScope(varargin)
            p = inputParser; p.addParameter('sim', true); p.parse(varargin{:});
            app.sim = logical(p.Results.sim);
            app.palette = lines(12);
            app.typeColors = containers.Map('KeyType','char','ValueType','any');
            app.proxyLines = containers.Map('KeyType','char','ValueType','any');
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
            cg = uigridlayout(cp, [16 2]);
            cg.RowHeight = repmat({26}, 1, 16); cg.ColumnWidth = {90, '1x'};

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

            app.startBtn = uibutton(cg,'state','Text','Start','ValueChangedFcn',@(s,~) app.onStartStop(s));
            app.startBtn.Layout.Column = [1 2];
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
            app.chAxes = gobjects(1,nCh); app.traceLines = cell(1,nCh); app.liveLines = gobjects(1,nCh);
            for c = 1:nCh
                ax = uiaxes(pg); grid(ax,'on'); hold(ax,'on');
                ylabel(ax, chNames{c});
                if c == nCh, xlabel(ax,'time from alignment (ms)'); end
                xline(ax, 0, 'Color',[0 0 0 0.5]);
                L = gobjects(1, app.nHold);
                for k = 1:app.nHold
                    L(k) = plot(ax, nan, nan, 'LineWidth', 1);   % coloured per task in redraw
                end
                app.traceLines{c} = L;
                app.liveLines(c) = plot(ax, nan, nan, 'LineWidth', 1.8);
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

            app.buildAxes(app.chAxes(1).Parent.Parent, app.channels);
            for c = 1:numel(app.chAxes), xlim(app.chAxes(c), [-app.preMs app.postMs]); end

            app.resetBuffers();
            app.held = struct('name',{},'t',{},'y',{});
            app.pending = struct('name',{},'t0',{},'endT',{});
            app.typeColors = containers.Map('KeyType','char','ValueType','any');
            app.lastAcqT = app.sourceNow();
            app.initSim();

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
                    if ~isempty(t)
                        rec.name = w.name; rec.t = t; rec.y = y; app.held(end+1) = rec; %#ok<AGROW>
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

        % --------------------------------------------------------- drawing
        function redraw(app)
            for c = 1:numel(app.channels)
                L = app.traceLines{c}; nh = numel(app.held);
                for k = 1:app.nHold
                    if k <= nh
                        rec = app.held(k);
                        set(L(k),'XData',rec.t,'YData',rec.y(c,:),'Color',app.colorForType(rec.name));
                    else
                        set(L(k),'XData',nan,'YData',nan);
                    end
                end
                if ~isempty(app.pending)
                    [t, y] = app.extractWindow(app.pending(end).t0);
                    if ~isempty(t)
                        set(app.liveLines(c),'XData',t,'YData',y(c,:),'Color',app.colorForType(app.curTrialName));
                    end
                else
                    set(app.liveLines(c),'XData',nan,'YData',nan);
                end
            end
            drawnow limitrate
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
                    legend(app.chAxes(1), ph, app.proxyLines.keys, 'Location','northeast', 'AutoUpdate','off');
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
            if app.sim, names = {'eyeX','eyeY','neural01','neural02','neural03'};
            else,       names = app.xippmexChannels(); end
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
                for c = 1:nCh
                    ymat(c,k) = app.simChannel(app.channels{c}, tt, trialT, hasTarget, tOnset);
                end
            end
            app.simState = s;
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

        % --- Phase 1 placeholders (xippmex) -------------------------------
        function names = xippmexChannels(~), names = {}; end
        function t = xippmexNow(~), t = double(xippmex('time'))/30000; end
        function [tvec, ymat, events] = acquireXippmex(~)
            tvec = zeros(1,0); ymat = []; events = struct('kind',{},'name',{},'t',{});
        end
    end
end
