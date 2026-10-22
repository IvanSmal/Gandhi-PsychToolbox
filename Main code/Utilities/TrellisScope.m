classdef TrellisScope < handle
%TRELLISSCOPE Real-time, state-aligned scope for Trellis channels.
%
%   A separate window of stacked plots. It opens with one plot; "+ Add plot"
%   adds more, and each plot has its own Modify and Remove buttons. Modify
%   opens the settings panel on the left for that plot:
%     - up to 5 channels, all drawn on the same axes (e.g. eyeX and eyeY);
%       spike channels are drawn as rasters on a right-hand axis, one row per
%       held trial (a block of rows per spike channel)
%     - the state to align on (t=0 at its onset), the [-pre, +post] ms window
%       and how many trials to hold
%     - colour by channel (older trials fainter) or by task type
%     - Y range (auto or fixed) and whether to mark the other states' onsets
%   Apply changes only that plot (its held trials restart); the others keep
%   running. The layout (plots and their settings) is saved in MATLAB's
%   preferences folder on this computer and restored the next time.
%
%   Overlay is BY STATE, not by task: every trial whose task contains a plot's
%   alignment state is captured for that plot. A trial that never enters the
%   state produces no window for it, so interleaved tasks that share a state
%   overlay together.
%
%   Design notes
%   ------------
%   * Driven by a TIMER, not a while-loop, so the window stays responsive.
%     Line objects are created when a plot is built and only their
%     XData/YData/Color are updated -- never plot()/cla in the loop -- with
%     drawnow limitrate. Held trials are redrawn only when they change; the
%     trial being captured is redrawn every tick.
%   * One rolling buffer holds every channel any plot shows (the union), so
%     two plots of the same channel read it once. Each plot keeps its own
%     pending and held windows.
%   * The data source is pluggable: a synthetic generator (no Trellis) or
%     xippmex ('cont' for channels, 'spike' for rasters; state onsets with NIP
%     ticks from the shared slot setstate writes). The acquire*/listChannels
%     methods are the only pluggable seam.
%
%   Usage:  TrellisScope            % synthetic source (demo)
%           TrellisScope('sim',0)   % real xippmex source (launchScope)

    properties
        fig                 % uifigure
        mainGrid            % [Modify panel | plots]
        plotArea            % panel holding the stacked plots
        modPanel            % the Modify panel (left column, hidden when closed)
        ctl                 % Modify panel controls
        startBtn; trialLbl; statusLbl; addBtn
        plots = []          % struct array, one element per plot (see newPlot)
        editId = 0          % id of the plot the Modify panel shows (0: closed)
        nextId = 1

        % data source
        sim = true
        fs = 1000
        chanList = {}
        channels = {}       % channels acquired: every channel any plot shows
        chanKind = {}       % 'cont' or 'spike', per acquired channel

        % rolling capture state
        tmr
        running = false
        bufT; bufY; bufFill = 0; bufN
        lastAcqT = 0
        curTrialName = ''
        seenStates = {}
        stateHist           % struct(name,t): recent state onsets
        simState

        % colours
        palette
        typeColors          % containers.Map: task name -> RGB
        chanColors          % containers.Map: channel name -> RGB

        % xippmex source
        chanMap             % containers.Map: friendly name -> struct(elec,type,unit,kind)
        inited = false
        eyeCal              % struct: xgain,xoffset,ygain,yoffset
        lastNipTick = []    % NIP tick of the last appended sample (dedup)
        nPull = 300         % samples to pull per tick (300 ms of history at 1 kHz)
        metaMap             % shared-memory slot: current trial name from MonkeyHost
        stateOnsetMap       % shared-memory slot: state onsets (name + NIP tick) from setstate
        lastOnsetSeq = 0    % highest state-onset seq already emitted
        lastTrialName = ''  % last trial name read from the slot
        spikeAccum          % containers.Map: channel name -> recent spike times (source clock, s)

        markPool = 80       % vertical-line pool per plot, for other-state onsets
        lastError           % the last error a tick caught (MException), for diagnosis
        busy = 0            % > 0 while plots or channels change: ticks wait (see holdTicks)
    end

    methods
        function app = TrellisScope(varargin)
            p = inputParser; p.addParameter('sim', true); p.parse(varargin{:});
            app.sim = logical(p.Results.sim);
            app.palette = lines(12);
            app.typeColors = containers.Map('KeyType','char','ValueType','any');
            app.chanColors = containers.Map('KeyType','char','ValueType','any');
            app.spikeAccum = containers.Map('KeyType','char','ValueType','any');
            app.stateHist = struct('name',{},'t',{});
            app.chanList = app.listChannels();
            app.bufN = 20000;                    % 20 s of history at 1 kHz
            app.buildUI();
            cfgs = app.loadLayout();
            for i = 1:numel(cfgs), app.plots = [app.plots app.newPlot(cfgs{i})]; end
            app.updateAcquisition();
            app.resetBuffers();
            app.layoutPlots();
        end

        % ---------------------------------------------------------------- UI
        function buildUI(app)
            app.fig = uifigure('Name','Trellis Scope', 'Position',[200 120 1100 680], ...
                'CloseRequestFcn', @(~,~) app.onClose());
            windowIdentity('Trellis Scope', 'trellisscope', app.fig);   % its own dock icon
            app.mainGrid = uigridlayout(app.fig, [1 2], 'ColumnWidth', {0, '1x'}, ...
                'RowHeight', {'1x'}, 'Padding', [6 6 6 6], 'ColumnSpacing', 6);
            app.buildModifyPanel();

            right = uigridlayout(app.mainGrid, [3 1], 'RowHeight', {26, '1x', 28}, ...
                'Padding', [0 0 0 0], 'RowSpacing', 4);
            right.Layout.Column = 2;
            top = uigridlayout(right, [1 3], 'ColumnWidth', {90, '1x', 220}, 'Padding', [0 0 0 0]);
            app.startBtn = uibutton(top, 'state', 'Text', 'Start', 'ValueChangedFcn', @(s,~) app.onStartStop(s));
            app.trialLbl = uilabel(top, 'Text', 'trial: --');
            app.statusLbl = uilabel(top, 'Text', 'idle', 'FontColor', [0.4 0.4 0.4], 'HorizontalAlignment', 'right');
            app.plotArea = uipanel(right, 'BorderType', 'none');
            bot = uigridlayout(right, [1 2], 'ColumnWidth', {110, '1x'}, 'Padding', [0 0 0 0]);
            app.addBtn = uibutton(bot, 'Text', '+ Add plot', 'ButtonPushedFcn', @(~,~) app.onAddPlot());
        end

        function buildModifyPanel(app)
            app.modPanel = uipanel(app.mainGrid, 'Title', 'Plot settings', 'Visible', 'off');
            app.modPanel.Layout.Column = 1;
            g = uigridlayout(app.modPanel, [19 2]);
            g.RowHeight = repmat({26}, 1, 19); g.ColumnWidth = {90, '1x'};
            h = uilabel(g, 'Text', 'Channels (drawn together):', 'FontWeight', 'bold'); h.Layout.Column = [1 2];
            app.ctl.ch = gobjects(1, 5);
            for k = 1:5
                app.ctl.ch(k) = uidropdown(g, 'Items', [{'(none)'} app.chanList], 'Value', '(none)');
                app.ctl.ch(k).Layout.Column = [1 2];
            end
            h = uilabel(g, 'Text', 'Align on state:', 'FontWeight', 'bold'); h.Layout.Column = [1 2];
            app.ctl.align = uidropdown(g, 'Items', {'(first state seen)'});
            app.ctl.align.Layout.Column = [1 2];
            uilabel(g, 'Text', 'Pre (ms):');
            app.ctl.pre = uieditfield(g, 'numeric', 'Limits', [0 60000], 'Value', 200);
            uilabel(g, 'Text', 'Post (ms):');
            app.ctl.post = uieditfield(g, 'numeric', 'Limits', [1 60000], 'Value', 500);
            uilabel(g, 'Text', 'Hold trials:');
            app.ctl.hold = uieditfield(g, 'numeric', 'Limits', [1 50], 'RoundFractionalValues', 'on', 'Value', 10);
            uilabel(g, 'Text', 'Colour by:');
            app.ctl.colorBy = uidropdown(g, 'Items', {'channel', 'task'});
            app.ctl.yAuto = uicheckbox(g, 'Text', 'Y auto', 'ValueChangedFcn', @(s,~) app.onYAutoCtl(s));
            app.ctl.yAuto.Layout.Column = [1 2];
            uilabel(g, 'Text', 'Y min:');
            app.ctl.yMin = uieditfield(g, 'numeric');
            uilabel(g, 'Text', 'Y max:');
            app.ctl.yMax = uieditfield(g, 'numeric');
            app.ctl.marks = uicheckbox(g, 'Text', 'Mark other states');
            app.ctl.marks.Layout.Column = [1 2];
            b = uigridlayout(g, [1 2], 'Padding', [0 0 0 0]); b.Layout.Column = [1 2];
            uibutton(b, 'Text', 'Apply', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) app.onApply());
            uibutton(b, 'Text', 'Close', 'ButtonPushedFcn', @(~,~) app.closeModify());
            h = uilabel(g, 'Text', 'Apply restarts this plot''s trials.', 'FontColor', [0.4 0.4 0.4]);
            h.Layout.Column = [1 2];
        end

        function P = newPlot(app, cfg)
            P = struct('id', app.nextId, 'cfg', cfg, 'ax', [], 'modBtn', [], 'remBtn', [], ...
                'cont', [], 'spk', [], 'heldL', {{}}, 'liveL', [], 'spkHeldL', {{}}, 'spkLiveL', [], ...
                'markL', [], 'taskProxy', [], ...
                'pending', struct('name',{},'t0',{},'endT',{}), ...
                'held', struct('name',{},'t',{},'y',{},'spk',{},'marks',{}), 'dirty', true);
            app.nextId = app.nextId + 1;
        end

        function c = defaultCfg(app)
            ch = app.chanList(ismember(app.chanList, {'eyeX', 'eyeY'}));
            if isempty(ch) && ~isempty(app.chanList), ch = app.chanList(1); end
            c = struct('channels', {ch}, 'alignState', '', 'preMs', 200, 'postMs', 500, 'nHold', 10, ...
                'colorBy', 'channel', 'yAuto', true, 'yMin', -1, 'yMax', 1, 'showMarks', true);
        end

        function layoutPlots(app)
            % (Re)build every plot's axes and lines from its settings; held
            % trials are kept and redrawn.
            h = app.holdTicks(); %#ok<NASGU>
            app.buildAllPlots();
            app.markEditing();
            app.redraw(true);
        end

        function h = holdTicks(app)
            % Hold the timer off until the caller returns. A timer callback can
            % run in the middle of any function here (seen between two property
            % assignments), so every change to the plots or the acquired
            % channels takes this first. Counted, so calls can nest.
            app.busy = app.busy + 1;
            h = onCleanup(@() app.releaseTicks());
        end

        function releaseTicks(app)
            app.busy = max(0, app.busy - 1);
        end

        function buildAllPlots(app)
            delete(app.plotArea.Children);
            n = numel(app.plots);
            pg = uigridlayout(app.plotArea, [max(n, 1) 2], 'ColumnWidth', {'1x', 78}, ...
                'RowHeight', repmat({'1x'}, 1, max(n, 1)), 'Padding', [0 0 0 0], 'RowSpacing', 4);
            for i = 1:n
                id = app.plots(i).id;
                ax = uiaxes(pg); ax.Layout.Row = i; ax.Layout.Column = 1;
                bg = uigridlayout(pg, [3 1], 'RowHeight', {26, 26, '1x'}, 'Padding', [0 0 0 0]);
                bg.Layout.Row = i; bg.Layout.Column = 2;
                app.plots(i).modBtn = uibutton(bg, 'Text', 'Modify', 'ButtonPushedFcn', @(~,~) app.openModify(id));
                app.plots(i).remBtn = uibutton(bg, 'Text', 'Remove', 'ButtonPushedFcn', @(~,~) app.onRemovePlot(id));
                app.plots(i).ax = ax;
                app.buildPlot(i);
            end
            if n == 1, app.plots(1).remBtn.Enable = 'off'; end   % keep at least one plot
        end

        function buildPlot(app, i)
            P = app.plots(i); c = P.cfg; ax = P.ax;
            kinds = cellfun(@(nm) app.kindOf(nm), c.channels, 'UniformOutput', false);
            P.cont = find(strcmp(kinds, 'cont'));
            P.spk = find(strcmp(kinds, 'spike'));
            hasSpk = ~isempty(P.spk);
            grid(ax, 'on');
            if hasSpk, yyaxis(ax, 'left'); end
            hold(ax, 'on');
            xline(ax, 0, 'Color', [0 0 0 0.6], 'LineWidth', 1);
            % pool of vertical lines for the OTHER (non-aligned) state onsets
            M = gobjects(1, app.markPool);
            for k = 1:app.markPool
                M(k) = xline(ax, NaN, 'LineWidth', 0.5, 'Interpreter', 'none'); M(k).Visible = 'off';
            end
            P.markL = M;
            % continuous channels: one line per held trial, plus the live one
            P.heldL = cell(1, numel(P.cont)); P.liveL = gobjects(1, numel(P.cont));
            for j = 1:numel(P.cont)
                L = gobjects(1, c.nHold);
                for k = 1:c.nHold, L(k) = plot(ax, nan, nan, 'LineStyle', '-', 'Marker', 'none', 'LineWidth', 1); end
                P.heldL{j} = L;
                P.liveL(j) = plot(ax, nan, nan, 'LineStyle', '-', 'Marker', 'none', 'LineWidth', 2);
            end
            % legend proxies (colour by channel: one per channel, now)
            proxies = gobjects(1, 0); names = {};
            if strcmp(c.colorBy, 'channel')
                for j = 1:numel(c.channels)
                    proxies(end+1) = plot(ax, nan, nan, 'Color', app.colorForChannel(c.channels{j}), ... %#ok<AGROW>
                        'LineStyle', '-', 'Marker', 'none', 'LineWidth', 2);
                    names{end+1} = c.channels{j}; %#ok<AGROW>
                end
            end
            P.taskProxy = containers.Map('KeyType', 'char', 'ValueType', 'any');
            if ~c.yAuto, ylim(ax, [c.yMin max(c.yMax, c.yMin + eps)]); end
            if ~isempty(P.cont)
                ylabel(ax, strjoin(c.channels(P.cont), ', '), 'Interpreter', 'none');
            end
            % spike channels: rasters on the right axis, a block of rows each
            P.spkHeldL = cell(1, numel(P.spk)); P.spkLiveL = gobjects(1, numel(P.spk));
            if hasSpk
                yyaxis(ax, 'right'); hold(ax, 'on');
                B = c.nHold + 2;
                for j = 1:numel(P.spk)
                    L = gobjects(1, c.nHold);
                    for k = 1:c.nHold
                        L(k) = plot(ax, nan, nan, 'LineStyle', 'none', 'Marker', '|', 'MarkerSize', 5, 'LineWidth', 1);
                    end
                    P.spkHeldL{j} = L;
                    P.spkLiveL(j) = plot(ax, nan, nan, 'LineStyle', 'none', 'Marker', '|', 'MarkerSize', 6, 'LineWidth', 1.5);
                end
                ylim(ax, [0.5, numel(P.spk) * B - 0.5]);
                ax.YAxis(2).TickValues = (0:numel(P.spk)-1) * B + (c.nHold + 1) / 2;
                ax.YAxis(2).TickLabels = c.channels(P.spk);
                ax.YAxis(2).TickLabelInterpreter = 'none';
                ax.YAxis(2).Color = [0.3 0.3 0.3];
                ylabel(ax, 'trials');
                yyaxis(ax, 'left');
                ax.YAxis(1).Color = [0.15 0.15 0.15];
            end
            xlim(ax, [-c.preMs c.postMs]);
            xlabel(ax, 'time from alignment (ms)');
            app.setTitle(ax, c);
            if ~isempty(proxies)
                legend(ax, proxies, names, 'Location', 'northeast', 'AutoUpdate', 'off', 'Interpreter', 'none');
            end
            try, enableDefaultInteractivity(ax); ax.Toolbar.Visible = 'on'; catch, end
            P.dirty = true;
            app.plots(i) = P;
        end

        function setTitle(~, ax, c)
            st = c.alignState; if isempty(st), st = '(first state seen)'; end
            title(ax, sprintf('%s  ·  aligned on %s', strjoin(c.channels, ', '), st), ...
                'FontWeight', 'normal', 'FontSize', 10, 'Interpreter', 'none');
        end

        function markEditing(app)
            for i = 1:numel(app.plots)
                b = app.plots(i).modBtn;
                if isempty(b) || ~isgraphics(b), continue, end
                if app.plots(i).id == app.editId
                    b.Text = 'Editing'; b.FontWeight = 'bold';
                else
                    b.Text = 'Modify'; b.FontWeight = 'normal';
                end
            end
        end

        % ---------------------------------------------------- Modify panel
        function openModify(app, id)
            i = app.plotIndex(id); if isempty(i), return, end
            c = app.plots(i).cfg;
            for k = 1:5
                app.ctl.ch(k).Items = [{'(none)'} app.chanList];
                if k <= numel(c.channels) && any(strcmp(app.chanList, c.channels{k}))
                    app.ctl.ch(k).Value = c.channels{k};
                else
                    app.ctl.ch(k).Value = '(none)';
                end
            end
            app.fillStateItems(c.alignState);
            app.ctl.pre.Value = c.preMs; app.ctl.post.Value = c.postMs; app.ctl.hold.Value = c.nHold;
            app.ctl.colorBy.Value = c.colorBy;
            app.ctl.yAuto.Value = c.yAuto;
            app.ctl.yMin.Value = c.yMin; app.ctl.yMax.Value = c.yMax;
            app.ctl.yMin.Enable = ~c.yAuto; app.ctl.yMax.Enable = ~c.yAuto;
            app.ctl.marks.Value = c.showMarks;
            app.modPanel.Title = sprintf('Plot %d settings', i);
            app.editId = id;
            app.modPanel.Visible = 'on';
            app.mainGrid.ColumnWidth = {270, '1x'};
            app.markEditing();
        end

        function closeModify(app)
            app.editId = 0;
            app.modPanel.Visible = 'off';
            app.mainGrid.ColumnWidth = {0, '1x'};
            app.markEditing();
        end

        function fillStateItems(app, cur)
            items = [{'(first state seen)'} app.seenStates];
            if ~isempty(cur) && ~any(strcmp(items, cur)), items{end+1} = cur; end
            app.ctl.align.Items = items;
            if isempty(cur), app.ctl.align.Value = items{1}; else, app.ctl.align.Value = cur; end
        end

        function onYAutoCtl(app, s)
            app.ctl.yMin.Enable = ~s.Value; app.ctl.yMax.Enable = ~s.Value;
            i = app.plotIndex(app.editId);
            if ~s.Value && ~isempty(i) && isgraphics(app.plots(i).ax)
                yl = app.plots(i).ax.YAxis(1).Limits;          % start from what is shown
                app.ctl.yMin.Value = yl(1); app.ctl.yMax.Value = yl(2);
            end
        end

        function onApply(app)
            h = app.holdTicks(); %#ok<NASGU>
            i = app.plotIndex(app.editId); if isempty(i), return, end
            ch = {};
            for k = 1:5
                v = app.ctl.ch(k).Value;
                if ~strcmp(v, '(none)') && ~any(strcmp(ch, v)), ch{end+1} = v; end %#ok<AGROW>
            end
            if isempty(ch)
                uialert(app.fig, 'Pick at least one channel.', 'Plot settings'); return
            end
            st = app.ctl.align.Value; if strcmp(st, '(first state seen)'), st = ''; end
            old = app.plots(i).cfg;
            c = struct('channels', {ch}, 'alignState', st, 'preMs', app.ctl.pre.Value, ...
                'postMs', app.ctl.post.Value, 'nHold', app.ctl.hold.Value, ...
                'colorBy', app.ctl.colorBy.Value, 'yAuto', app.ctl.yAuto.Value, ...
                'yMin', app.ctl.yMin.Value, 'yMax', app.ctl.yMax.Value, 'showMarks', app.ctl.marks.Value);
            app.plots(i).cfg = c;
            if ~isequal(old.channels, c.channels) || ~strcmp(old.alignState, c.alignState) || ...
                    old.preMs ~= c.preMs || old.postMs ~= c.postMs || old.nHold ~= c.nHold
                app.plots(i).pending = app.plots(i).pending([]);
                app.plots(i).held = app.plots(i).held([]);
            end
            app.updateAcquisition();
            app.layoutPlots();
            app.saveLayout();
            app.statusLbl.Text = sprintf('plot %d updated', i);
        end

        function onAddPlot(app)
            h = app.holdTicks(); %#ok<NASGU>
            app.plots = [app.plots app.newPlot(app.defaultCfg())];
            app.updateAcquisition();
            app.layoutPlots();
            app.saveLayout();
            app.openModify(app.plots(end).id);       % set the new plot up right away
        end

        function onRemovePlot(app, id)
            h = app.holdTicks(); %#ok<NASGU>
            i = app.plotIndex(id);
            if isempty(i) || isscalar(app.plots), return, end
            if app.editId == id, app.closeModify(); end
            app.plots(i) = [];
            app.updateAcquisition();
            app.layoutPlots();
            app.saveLayout();
        end

        function i = plotIndex(app, id)
            if isempty(app.plots), i = []; return, end
            i = find([app.plots.id] == id, 1);
        end

        % ---------------------------------------------- layout persistence
        function f = layoutFile(~)
            f = fullfile(prefdir, 'TrellisScopeLayout.mat');
        end

        function saveLayout(app)
            try
                cfgs = {app.plots.cfg};
                save(app.layoutFile(), 'cfgs');
            catch
            end
        end

        function cfgs = loadLayout(app)
            % The saved plots, keeping only channels this computer offers; one
            % default plot if there is nothing (usable) saved.
            cfgs = {};
            try
                s = load(app.layoutFile(), 'cfgs');
                def = app.defaultCfg();
                for i = 1:numel(s.cfgs)
                    c = def;
                    for f = fieldnames(def)'
                        if isfield(s.cfgs{i}, f{1}), c.(f{1}) = s.cfgs{i}.(f{1}); end
                    end
                    c.channels = c.channels(ismember(c.channels, app.chanList));
                    if ~isempty(c.channels), cfgs{end+1} = c; end %#ok<AGROW>
                end
            catch
            end
            if isempty(cfgs), cfgs = {app.defaultCfg()}; end
        end

        function onClose(app)
            app.saveLayout();
            app.endRun();
            delete(app.fig);
        end

        % ------------------------------------------------------- start/stop
        function onStartStop(app, src)
            if src.Value, app.beginRun(); src.Text = 'Stop';
            else,         app.endRun();   src.Text = 'Start'; end
        end

        function beginRun(app)
            h = app.holdTicks(); %#ok<NASGU>
            app.updateAcquisition();
            app.resetBuffers();
            for i = 1:numel(app.plots)
                app.plots(i).pending = app.plots(i).pending([]);
                app.plots(i).held = app.plots(i).held([]);
                app.plots(i).dirty = true;
            end
            app.stateHist = struct('name',{},'t',{});
            app.spikeAccum = containers.Map('KeyType','char','ValueType','any');
            app.stateOnsetMap = []; app.lastOnsetSeq = 0;
            try   % skip onsets already in the ring so only NEW ones show
                m0 = sceneOpen(false, stateOnsetPath());
                [f0,ok0] = sceneRead(m0);
                if ok0 && isstruct(f0) && isfield(f0,'onsets') && ~isempty(f0.onsets)
                    app.lastOnsetSeq = max([f0.onsets.seq]);
                end
            catch
            end
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
            if isvalid(app.fig) && isgraphics(app.statusLbl)
                app.statusLbl.Text = 'stopped'; app.statusLbl.FontColor = [0.4 0.4 0.4];
            end
        end

        % ------------------------------------------------------- main tick
        function tick(app)
            if ~app.running || app.busy > 0 || ~isvalid(app.fig), return; end
            try
                [chunkT, chunkY, events] = app.acquire();
                app.pushSamples(chunkT, chunkY);
                app.handleEvents(events);
                app.completePending();
                app.redraw(false);
            catch e
                app.lastError = e;
                app.statusLbl.Text = ['error: ' e.message]; app.statusLbl.FontColor = [0.8 0 0];
            end
        end

        function updateAcquisition(app)
            % Acquire the union of every plot's channels. A channel that is new
            % to the buffer starts with NaN history; others keep theirs.
            want = {};
            for i = 1:numel(app.plots)
                c = app.plots(i).cfg.channels;
                want = [want c(~ismember(c, want))]; %#ok<AGROW>
            end
            if isequal(want, app.channels), return, end
            newY = nan(numel(want), app.bufN);
            for k = 1:numel(want)
                j = find(strcmp(app.channels, want{k}), 1);
                if ~isempty(j) && size(app.bufY, 1) >= j, newY(k, :) = app.bufY(j, :); end
            end
            app.bufY = newY;
            app.channels = want;
            app.chanKind = cellfun(@(nm) app.kindOf(nm), want, 'UniformOutput', false);
        end

        function pushSamples(app, tvec, ymat)
            n = numel(tvec); if n == 0, return; end
            idx = mod(app.bufFill + (0:n-1), app.bufN) + 1;
            app.bufT(idx) = tvec;
            if ~isempty(app.bufY), app.bufY(:, idx) = ymat; end
            app.bufFill = app.bufFill + n; app.lastAcqT = tvec(end);
        end

        function handleEvents(app, events)
            for e = 1:numel(events)
                ev = events(e);
                switch ev.kind
                    case 'trial'
                        app.curTrialName = ev.name; app.trialLbl.Text = ['trial: ' ev.name];
                    case 'state'
                        if ~any(strcmp(app.seenStates, ev.name))
                            app.seenStates{end+1} = ev.name;
                            if app.editId ~= 0, app.fillStateItems(app.stateValue()); end
                        end
                        app.stateHist(end+1) = struct('name',ev.name,'t',ev.t);
                        if numel(app.stateHist) > 500, app.stateHist = app.stateHist(end-499:end); end
                        for i = 1:numel(app.plots)
                            if isempty(app.plots(i).cfg.alignState)   % no choice yet: the first state seen
                                app.plots(i).cfg.alignState = ev.name;
                                if ~isempty(app.plots(i).ax) && isgraphics(app.plots(i).ax)
                                    app.setTitle(app.plots(i).ax, app.plots(i).cfg);
                                end
                            end
                            if strcmp(ev.name, app.plots(i).cfg.alignState)
                                app.plots(i).pending(end+1) = struct('name', app.curTrialName, 't0', ev.t, ...
                                    'endT', ev.t + app.plots(i).cfg.postMs/1000);
                            end
                        end
                end
            end
        end

        function v = stateValue(app)
            v = app.ctl.align.Value; if strcmp(v, '(first state seen)'), v = ''; end
        end

        function completePending(app)
            for i = 1:numel(app.plots)
                P = app.plots(i); c = P.cfg;
                keep = true(1, numel(P.pending));
                for p = 1:numel(P.pending)
                    w = P.pending(p);
                    if app.lastAcqT >= w.endT
                        [t, y] = app.extractWindow(w.t0, c.preMs, c.postMs, c.channels(P.cont));
                        spk = cell(1, numel(P.spk));
                        for j = 1:numel(P.spk)
                            spk{j} = app.extractSpikes(w.t0, c.preMs, c.postMs, c.channels{P.spk(j)});
                        end
                        if ~isempty(t) || ~isempty(P.spk)
                            P.held(end+1) = struct('name', w.name, 't', t, 'y', y, 'spk', {spk}, ...
                                'marks', app.windowMarks(w.t0, c.preMs, c.postMs));
                            P.dirty = true;
                        end
                        keep(p) = false;
                    end
                end
                P.pending = P.pending(keep);
                if numel(P.held) > c.nHold, P.held = P.held(end-c.nHold+1:end); end
                app.plots(i) = P;
            end
        end

        function [t, y] = extractWindow(app, t0, preMs, postMs, names)
            t = []; y = [];
            if app.bufFill == 0, return; end
            n = min(app.bufFill, app.bufN);
            idx = mod((app.bufFill-n) + (0:n-1), app.bufN) + 1;
            tt = app.bufT(idx);
            sel = tt >= t0 - preMs/1000 & tt <= t0 + postMs/1000;
            if ~any(sel), return; end
            t = (tt(sel) - t0) * 1000;
            [~, rows] = ismember(names, app.channels);
            y = nan(numel(names), numel(t));
            ii = idx(sel);
            for j = 1:numel(names)
                if rows(j) > 0, y(j, :) = app.bufY(rows(j), ii); end
            end
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

        function sp = extractSpikes(app, t0, preMs, postMs, name)
            % Spike times within [-pre, +post] of t0, relative to t0, in ms.
            sp = zeros(1,0);
            if ~isKey(app.spikeAccum, name), return; end
            tv = app.spikeAccum(name);
            sel = tv >= t0 - preMs/1000 & tv <= t0 + postMs/1000;
            sp = (tv(sel) - t0) * 1000;
        end

        % --------------------------------------------------------- drawing
        function redraw(app, force)
            for i = 1:numel(app.plots)
                P = app.plots(i); c = P.cfg;
                if isempty(P.ax) || ~isgraphics(P.ax), continue, end
                if P.dirty || force
                    app.drawHeld(i);
                    app.plots(i).dirty = false;
                end
                % the trial being captured: every tick, full colour, thicker
                if ~isempty(P.pending)
                    w = P.pending(end);
                    [t, y] = app.extractWindow(w.t0, c.preMs, c.postMs, c.channels(P.cont));
                    for j = 1:numel(P.cont)
                        col = app.traceColor(c, c.channels{P.cont(j)}, w.name, 1, 1);
                        if isempty(t), set(P.liveL(j), 'XData', nan, 'YData', nan);
                        else, set(P.liveL(j), 'XData', t, 'YData', y(j, :), 'Color', col); end
                    end
                    B = c.nHold + 2;
                    for j = 1:numel(P.spk)
                        sp = app.extractSpikes(w.t0, c.preMs, c.postMs, c.channels{P.spk(j)});
                        col = app.traceColor(c, c.channels{P.spk(j)}, w.name, 1, 1);
                        set(P.spkLiveL(j), 'XData', sp, 'YData', ((j-1)*B + c.nHold + 1) * ones(1, numel(sp)), 'Color', col);
                    end
                else
                    set(P.liveL, 'XData', nan, 'YData', nan);
                    set(P.spkLiveL, 'XData', nan, 'YData', nan);
                end
            end
            drawnow limitrate
        end

        function drawHeld(app, i)
            P = app.plots(i); c = P.cfg; nh = numel(P.held); B = c.nHold + 2;
            for j = 1:numel(P.cont)
                L = P.heldL{j};
                for k = 1:c.nHold
                    if k <= nh && ~isempty(P.held(k).t)
                        rec = P.held(k);
                        set(L(k), 'XData', rec.t, 'YData', rec.y(j, :), ...
                            'Color', app.traceColor(c, c.channels{P.cont(j)}, rec.name, k, nh));
                    else
                        set(L(k), 'XData', nan, 'YData', nan);
                    end
                end
            end
            for j = 1:numel(P.spk)
                L = P.spkHeldL{j};
                for k = 1:c.nHold
                    if k <= nh
                        rec = P.held(k); sp = rec.spk{j};
                        set(L(k), 'XData', sp, 'YData', ((j-1)*B + k) * ones(1, numel(sp)), ...
                            'Color', app.traceColor(c, c.channels{P.spk(j)}, rec.name, k, nh));
                    else
                        set(L(k), 'XData', nan, 'YData', nan);
                    end
                end
            end
            % other-state markers: every held window's non-aligned onsets,
            % coloured per state; only the newest window is labelled
            M = P.markL; mi = 0;
            if c.showMarks
                for k = 1:nh
                    mk = P.held(k).marks;
                    for m = 1:numel(mk)
                        mi = mi + 1; if mi > app.markPool, break; end
                        M(mi).Value = mk(m).rel; M(mi).Color = app.colorForMark(mk(m).name);
                        M(mi).Visible = 'on';
                        if k == nh, M(mi).Label = mk(m).name; else, M(mi).Label = ''; end
                    end
                    if mi > app.markPool, break; end
                end
            end
            for k = mi+1:app.markPool, M(k).Visible = 'off'; M(k).Label = ''; end
            % colour by task: one legend entry per task seen in this plot
            if strcmp(c.colorBy, 'task')
                newTask = false;
                for k = 1:nh
                    nm = P.held(k).name; if isempty(nm), nm = '(unnamed)'; end
                    if ~isKey(P.taskProxy, nm)
                        if ~isempty(P.spk), yyaxis(P.ax, 'left'); end
                        P.taskProxy(nm) = plot(P.ax, nan, nan, 'Color', app.colorForType(nm), ...
                            'LineStyle', '-', 'Marker', 'none', 'LineWidth', 2);
                        newTask = true;
                    end
                end
                if newTask
                    ph = P.taskProxy.values; ph = [ph{:}];
                    legend(P.ax, ph, P.taskProxy.keys, 'Location', 'northeast', 'AutoUpdate', 'off', 'Interpreter', 'none');
                end
            end
        end

        function col = traceColor(app, c, chan, task, k, nh)
            % Channel or task colour, faded toward white for older trials
            % (k = 1 oldest .. nh newest).
            if strcmp(c.colorBy, 'task'), base = app.colorForType(task);
            else, base = app.colorForChannel(chan); end
            w = 0.3 + 0.7 * (k - 1) / max(nh - 1, 1);
            if nh <= 1, w = 1; end
            col = base * w + [1 1 1] * (1 - w);
        end

        function col = colorForChannel(app, name)
            % The same channel always gets the same colour, in every plot and
            % every session: fixed for the eye and photodiode, otherwise picked
            % from the name (not from the order channels are first used).
            if ~isKey(app.chanColors, name)
                fixed = struct('eyeX', [0 0.447 0.741], 'eyeY', [0.850 0.325 0.098], 'photodiode', [0.4 0.4 0.4]);
                others = [0.494 0.184 0.556; 0.466 0.674 0.188; 0.301 0.745 0.933; 0.635 0.078 0.184; ...
                          0.929 0.694 0.125; 0.85 0.10 0.60; 0.10 0.55 0.50; 0.55 0.35 0.15];
                key = matlab.lang.makeValidName(name);
                if isfield(fixed, key)
                    app.chanColors(name) = fixed.(key);
                else
                    h = 5381;                                   % djb2 string hash: names that differ
                    for ch = double(name)                       % only in the last digit (spk 1, spk 2)
                        h = mod(h * 33 + ch, 2^31);             % get neighbouring colours
                    end
                    app.chanColors(name) = others(mod(h, size(others, 1)) + 1, :);
                end
            end
            col = app.chanColors(name);
        end

        function col = colorForType(app, name)
            if isempty(name), name = '(unnamed)'; end
            if ~isKey(app.typeColors, name)
                idx = app.typeColors.Count + 1;
                app.typeColors(name) = app.palette(mod(idx-1, size(app.palette,1)) + 1, :);
            end
            col = app.typeColors(name);
        end

        function marks = windowMarks(app, t0, preMs, postMs)
            marks = struct('name',{},'rel',{});
            if isempty(app.stateHist), return; end
            tt = [app.stateHist.t];
            sel = tt >= t0-preMs/1000 & tt <= t0+postMs/1000 & abs(tt-t0) > 0.001;
            for j = find(sel)
                marks(end+1) = struct('name',app.stateHist(j).name, ...
                    'rel',(app.stateHist(j).t-t0)*1000); %#ok<AGROW>
            end
        end

        function col = colorForMark(app, name)
            persistent markColors
            if isempty(markColors), markColors = containers.Map('KeyType','char','ValueType','any'); end
            if ~isKey(markColors, name)
                idx = markColors.Count + 1;
                base = app.palette(mod(idx-1,size(app.palette,1))+1,:);
                markColors(name) = 0.45*base + 0.55*[1 1 1];   % muted
            end
            col = markColors(name);
        end

        function resetBuffers(app)
            app.bufT = zeros(1, app.bufN);
            app.bufY = nan(numel(app.channels), app.bufN);
            app.bufFill = 0;
        end

        % =============================================== DATA SOURCE (pluggable)
        function names = listChannels(app)
            if app.sim, names = {'eyeX','eyeY','neural01','neural02','spikes01','spikes02'};
            else,       names = app.xippmexChannels(); end
        end

        function k = kindOf(app, name)
            if app.sim
                if startsWith(name,'spikes'), k = 'spike'; else, k = 'cont'; end
            elseif ~isempty(app.chanMap) && isKey(app.chanMap, name)
                k = app.chanMap(name).kind;
            else
                k = 'cont';
            end
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
