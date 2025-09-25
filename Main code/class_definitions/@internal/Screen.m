function varargout = Screen(mh, varargin)
% Create a simpler hash for comparison
try
    % Faster hashing approach using typecast for numeric operations
    hashValues = zeros(1, length(varargin), 'double');
    for i = 1:length(varargin)
        if isnumeric(varargin{i})
            % Use direct sum on vectorized data without double conversion
            hashValues(i) = sum(varargin{i}(:));
        elseif ischar(varargin{i})
            % Avoid double conversion for character arrays
            hashValues(i) = sum(uint8(varargin{i}));
        elseif isstring(varargin{i})
            % Convert string to char first for faster processing
            hashValues(i) = sum(uint8(char(varargin{i})));
        elseif isobject(varargin{i})
            hashValues(i) = i * 1000; % Simple object identifier
        else
            hashValues(i) = i;
        end
    end
    cmd_hash = sprintf('%d', sum(hashValues));
catch
    % Fallback if hashing fails
    cmd_hash = sprintf('%d', randi(1000000));
end

% Fast path for cached output
if strcmp(mh.cachedout, cmd_hash) || mh.holdbuffer
    % If command is 'sendtogr', process that separately
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
        % Clear buffer more efficiently
        if strcmpi(varargin{1}, 'clearbuffer')
            matlabUDP2('send',mh.graphicsport, 'executegr.functionsbuffer=[];');
        elseif strcmpi(varargin{1}, 'sendtogr') && ~isempty(mh.graphicscommandbuffer)
            processSendToGr(mh);
        end
        return;
    end
end

% Preallocate command string with estimated size
numArgs = length(varargin);
estimatedCmdLength = numArgs * 50; % Estimate average 50 chars per argument
cmdStr = strings(1, numArgs + 2); % +2 for additional commands
cmdIdx = 1;

% Process arguments
for i = 1:numArgs
    cmdStr(cmdIdx) = sprintf('args_udp{%d}=%s;', mh.lastcommand, formatArgument(mh, varargin{i}, i));
    cmdIdx = cmdIdx + 1;
    mh.lastcommand = mh.lastcommand + 1;
end

% Handle texture case - faster string manipulation
if numArgs > 0 && strcmpi(varargin{1}, 'DrawTexture') && numArgs >= 3
    if ischar(varargin{3}) || isstring(varargin{3})
        varval = strrep(varargin{3}, '.texture', '.monitortexture');
        cmdStr(cmdIdx) = sprintf('additionalinfo_udp{1}=%s;', varval);
        cmdIdx = cmdIdx + 1;
    end
end

% Handle output variables more efficiently
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

% Join strings - more efficient than strjoin on cell arrays
mh.graphicscommandbuffer = mh.graphicscommandbuffer + join(cmdStr(1:cmdIdx), '');

% Handle output retrieval
if nargout > 0
    commands = matlabUDP2('receive',mh.graphicsport);
    eval(commands);  % Consider replacing with more efficient code if possible
    
    % Preallocate output
    varargout = cell(nargout, 1);
    for i = 1:nargout
        varargout{i} = eval(['a' num2str(i)]);  % Consider more efficient approach
    end
end

end

function processSendToGr(mh)
% Extracted sendtogr logic for cleaner code organization
if mh.commandID == 0
    mh.commandID = getsecs;
end

% Send state name once - combine operations
mh.evalgraphics(['gr.activestatename =''' mh.activestatename ''';']);
matlabUDP2('send',mh.graphicsport, mh.activestatename);

% Send commands in one batch - faster string formatting
cmdBatch = strjoin([mh.graphicscommandbuffer, ';commandID_udp=', num2str(mh.commandID), ';']);
    
    matlabUDP2('send',mh.graphicsport, cmdBatch);

% Reset state
mh.lastsenttime = getsecs;
mh.graphicscommandbuffer = '';
mh.lastcommand = 1;
mh.holdbuffer = 0;
mh.commandID = 0;
end

function formatted = formatArgument(mh, arg, argIdx)
% Optimized argument formatting function
if ischar(arg)
    if contains(arg, 'gr')
        formatted = arg;
    else
        formatted = ['''' arg ''''];
    end
elseif isnumeric(arg)
    % More efficient numeric conversion
    formatted = mat2str(arg);
elseif isobject(arg)
    % Optimize object handling
    targname = arg.name;
    pos = mh.trialtarg(targname, 'getpos');
    formatted = mat2str(pos);
else
    formatted = ['''' inputname(argIdx) ''''];
end
end