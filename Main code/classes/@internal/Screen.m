function varargout = Screen(mh, varargin)
% Create a simple random hash for this command
try
    cmd_hash = sprintf('%d', randi(10000000));
end

% Fast path for cached output
if strcmp(mh.cachedout, cmd_hash) || mh.holdbuffer
    if nargin > 1 && strcmpi(varargin{1}, 'sendtogr') && ~isempty(mh.graphicscommandbuffer)
        processSendToGr(mh);
    end
    return;
end

% Update cache hash
mh.cachedout = cmd_hash;

% Handle special commands
if nargin > 1
    if strcmpi(varargin{1}, 'clearbuffer') || strcmpi(varargin{1}, 'sendtogr')
        if strcmpi(varargin{1}, 'clearbuffer')
            matlabUDP_gandhi('send', mh.graphicsport, 'executegr.functionsbuffer=[];');
        elseif strcmpi(varargin{1}, 'sendtogr') && ~isempty(mh.graphicscommandbuffer)
            processSendToGr(mh);
        end
        return;
    end
end

% Build command string for this Screen call
numArgs = length(varargin);
cmdStr = strings(1, numArgs + 2);
cmdIdx = 1;

% Process arguments
for i = 1:numArgs
    cmdStr(cmdIdx) = sprintf('args_udp{%d}=%s;', mh.lastcommand, formatArgument(mh, varargin{i}, i));
    cmdIdx = cmdIdx + 1;
    mh.lastcommand = mh.lastcommand + 1;
end

% Handle texture case
if numArgs > 0 && strcmpi(varargin{1}, 'DrawTexture') && numArgs >= 3
    if ischar(varargin{3}) || isstring(varargin{3})
        varval = strrep(varargin{3}, '.texture', '.monitortexture');
        cmdStr(cmdIdx) = sprintf('additionalinfo_udp{1}=%s;', varval);
        cmdIdx = cmdIdx + 1;
    end
end

% Handle output variables
if nargout > 0
    outStr = strings(1, nargout);
    for i = 1:nargout
        outStr(i) = sprintf('outs_udp{%d}=''a%d'';', i, i);
    end
    cmdStr(cmdIdx) = join(outStr, '');
    cmdIdx = cmdIdx + 1;
end

% Add delimiter
cmdStr(cmdIdx) = sprintf('args_udp{%d}=''endcommand'';', mh.lastcommand);
mh.lastcommand = mh.lastcommand + 1;

% Accumulate into buffer (kept as char throughout)
mh.graphicscommandbuffer = [mh.graphicscommandbuffer, char(join(cmdStr(1:cmdIdx), ''))];

% Handle output retrieval (blocking receive loop)
if nargout > 0
    com = '';
    t = tic;
    while isempty(com) && toc(t) < 1
        com = matlabUDP_gandhi('receive', mh.graphicsport);
    end
    eval(com);

    varargout = cell(nargout, 1);
    for i = 1:nargout
        varargout{i} = eval(['a' num2str(i)]);
    end
end

end

function processSendToGr(mh)
if mh.commandID == 0
    mh.commandID = getsecs;
end

% Send active state name
mh.evalgraphics(['gr.activestatename =''' mh.activestatename ''';']);
matlabUDP_gandhi('send', mh.graphicsport, char(mh.activestatename));

% Send full command batch — explicitly char() since strcat/[] may yield string
cmdBatch = [mh.graphicscommandbuffer, ';commandID_udp=', num2str(mh.commandID), ';'];
matlabUDP_gandhi('send', mh.graphicsport, char(cmdBatch));

% Reset state
mh.lastsenttime = getsecs;
mh.graphicscommandbuffer = '';
mh.lastcommand = 1;
mh.holdbuffer = 0;
mh.commandID = 0;
end

function formatted = formatArgument(mh, arg, argIdx)
if ischar(arg)
    if contains(arg, 'gr')
        formatted = arg;
    else
        formatted = ['''' arg ''''];
    end
elseif isnumeric(arg)
    formatted = mat2str(arg);
elseif isobject(arg)
    targname = arg.name;
    pos = mh.trialtarg(targname, 'getpos');
    formatted = mat2str(pos);
else
    formatted = ['''' inputname(argIdx) ''''];
end
end