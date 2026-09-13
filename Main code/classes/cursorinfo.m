classdef cursorinfo < handle
%CURSORINFO A pointer input parallel to eyeinfo, but calibrated in MILLIMETRES.
%   One cursorinfo drives one on-screen cursor. Its raw signal comes from
%   either analog channels (like the eye) or a UDP joystick, is converted to
%   millimetres of screen position (raw*gain + offset), and then to display
%   pixels via deg2pix(...,'mm'). getcursor returns pixels so checkcursor can
%   compare against target positions exactly like checkeye does for the eye.
%
%   The assignment (source, channels, port, calibration, enabled) is read from
%   the state ini section [cursorN] in the constructor, so File > Cursor
%   Assignment just writes the ini and rebuilds. Everything here is additive:
%   eye-only tasks never construct a cursorinfo.
%
%   UDP ownership: a UDP port can be bound by only ONE process. GraphicsHandler
%   (the renderer) constructs its cursors with owner=true, so it alone binds the
%   socket; every frame it reads the joystick and publishes the position to a
%   shared slot (cursorSlotPath). The task process's cursorinfo (owner=false, the
%   default) reads that slot instead of binding the port. Analog cursors ignore
%   owner entirely -- both processes can read the DAQ.

    properties
        id      = 1              % 1..5; matches the mouse-mode target 'cursorN' and the ini section
        enabled = false          % only enabled cursors are created/tracked
        source  = 'analog'       % 'analog' | 'udp'
        xchan   = []             % analog channel id for x (analog source)
        ychan   = []             % analog channel id for y
        udpLocalPort = []        % local UDP port to listen on (udp source)

        % raw signal -> millimetres of screen (about the true center, +y up)
        xgain   = 1
        ygain   = 1
        xoffset = 0
        yoffset = 0

        x = 0                    % last position, display pixels
        y = 0
        screenparams = []        % passed to deg2pix; [] -> read the rig config
        udpobj = []              % lazily-opened udpport for the udp source

        owner   = false          % true: this process owns the UDP socket and publishes the slot
        gotdata = false          % true once a real position has been read (so the renderer
                                 % does not draw a udp cursor at its (0,0) default before the
                                 % joystick has ever sent)
        slotMap     = []         % owner: memmap for publishing the shared cursor slot
        slotSeq     = 0          % owner: seqlock counter
        slotReadMap = []         % non-owner: memmap for reading the shared cursor slot
    end

    methods
        function obj = cursorinfo(id, varargin)
            if nargin >= 1 && ~isempty(id), obj.id = id; end
            % read the assignment from the state ini section [cursorN]
            try
                ini = rigIni('state'); sec = sprintf('cursor%d', obj.id);
                obj.enabled      = logical(cursorGet(ini,sec,'enabled',0));
                obj.source       = cursorGet(ini,sec,'source','analog');
                obj.xchan        = cursorGet(ini,sec,'xchan',[]);
                obj.ychan        = cursorGet(ini,sec,'ychan',[]);
                obj.udpLocalPort = cursorGet(ini,sec,'udpport',[]);
                obj.xgain        = cursorGet(ini,sec,'xgain',1);
                obj.ygain        = cursorGet(ini,sec,'ygain',1);
                obj.xoffset      = cursorGet(ini,sec,'xoffset',0);
                obj.yoffset      = cursorGet(ini,sec,'yoffset',0);
            catch
            end
            % explicit name/value overrides win (used by tests / direct construction)
            for i = 1:2:numel(varargin)
                obj.(varargin{i}) = varargin{i+1};
            end
        end

        function out = getcursor(obj)
            % Mouse mode aimed at this cursor wins (returns display pixels).
            mp = readMouseSlot(sprintf('cursor%d', obj.id));
            if ~isempty(mp)
                obj.x = mp(1); obj.y = mp(2); obj.gotdata = true; out = round(mp); return
            end
            mm = obj.rawmm();
            if isempty(mm)
                out = round([obj.x obj.y]); return    % unassigned / no packet: hold last
            end
            obj.gotdata = true;
            pix = deg2pix([mm(1) mm(2)], 'mm', obj.screenparams);
            obj.x = pix(1); obj.y = pix(2);
            out = round(pix);
        end

        function out = getrawcursor(obj)
            % Raw millimetres (pre-pixel), or the last held position if none.
            out = obj.rawmm();
            if isempty(out), out = [obj.x obj.y]; end
        end

        function mm = rawmm(obj)
            mm = [];
            if strcmpi(obj.source, 'udp')
                if obj.owner
                    % this process owns the socket: read it and share the value
                    pkt = obj.readudp();
                    if ~isempty(pkt)
                        mm = pkt;
                        obj.publishslot(pkt);
                    end
                else
                    % the renderer owns the socket: read the value it published
                    s = obj.readslot();
                    if ~isempty(s), mm = s; end
                end
            else
                if isempty(obj.xchan) || isempty(obj.ychan), return; end
                rawx = xippmex('cont', obj.xchan, 1, '1ksps');
                rawy = xippmex('cont', obj.ychan, 1, '1ksps');
                mm = [rawx*obj.xgain + obj.xoffset, rawy*obj.ygain + obj.yoffset];
            end
        end

        function mm = readudp(obj)
            % Lowest-latency read: drain the socket, keep only the newest
            % datagram (two little-endian doubles = x,y in mm). Non-blocking.
            mm = [];
            try
                if isempty(obj.udpobj)
                    if isempty(obj.udpLocalPort), return; end
                    obj.udpobj = udpport('datagram', 'LocalPort', obj.udpLocalPort);
                end
                last = [];
                while obj.udpobj.NumDatagramsAvailable > 0
                    last = read(obj.udpobj, 1, 'uint8');   % newest wins
                end
                if ~isempty(last) && numel(last.Data) >= 16
                    v = typecast(uint8(last.Data(1:16)), 'double');
                    mm = [v(1)*obj.xgain + obj.xoffset, v(2)*obj.ygain + obj.yoffset];
                end
            catch
            end
        end

        function publishslot(obj, mm)
            % Owner only: publish this cursor's mm position to its shared slot so
            % the task process can read it without binding the UDP port.
            try
                if isempty(obj.slotMap)
                    obj.slotMap = sceneOpen(true, cursorSlotPath(obj.id));
                end
                obj.slotSeq = obj.slotSeq + 1;
                sceneWrite(obj.slotMap, obj.slotSeq, ...
                    struct('on',1,'x',mm(1),'y',mm(2),'t',getsecs));
            catch
                obj.slotMap = [];   % slot went away: reopen next call
            end
        end

        function mm = readslot(obj)
            % Non-owner: newest mm from the shared cursor slot, or [] if the
            % renderer has not published a fresh value (>1 s old = stale, so a
            % dead renderer never leaves the cursor stuck at an old position).
            mm = [];
            try
                if isempty(obj.slotReadMap)
                    p = cursorSlotPath(obj.id);
                    if ~isfile(p), return; end
                    obj.slotReadMap = sceneOpen(false, p);
                end
                [d, ok] = sceneRead(obj.slotReadMap);
                if ok && isstruct(d) && isfield(d,'on') && d.on == 1 ...
                        && isfield(d,'t') && (getsecs - d.t) < 1
                    mm = [d.x d.y];
                end
            catch
                obj.slotReadMap = [];   % slot went away: reopen next call
            end
        end
    end
end

function v = cursorGet(ini, sec, key, default)
% Read one ini key with a fallback (missing section/key -> default).
    try, v = ini.GetValues(sec, key); catch, v = []; end
    if isempty(v), v = default; end
end
