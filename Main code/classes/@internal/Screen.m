function varargout = Screen(mh, varargin)
% Create a simpler hash for comparison
try
    % Safer hashing approach
    hashValues = zeros(1, length(varargin));
    for i = 1:length(varargin)
        if isnumeric(varargin{i})
            hashValues(i) = sum(double(varargin{i}(:)));
        elseif ischar(varargin{i}) || isstring(varargin{i})
            hashValues(i) = sum(double(varargin{i}));
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

if ~strcmp(mh.cachedout, cmd_hash) && ~mh.holdbuffer
    mh.cachedout = cmd_hash;

    if ~strcmpi(varargin{1}, 'clearbuffer') && ~strcmpi(varargin{1}, 'sendtogr')
        % Preallocate cell array for commands
        cmdParts = cell(length(varargin)*2 + 2);
        cmdIdx = 1;

        for i = 1:length(varargin)
            argVal = formatArgument(mh, varargin{i}, i);
            cmdParts{cmdIdx} = sprintf('args_udp{%d}=%s;', mh.lastcommand, argVal);
            cmdIdx = cmdIdx + 1;
            mh.lastcommand = mh.lastcommand + 1;
        end

        % Handle texture case
        if strcmpi(varargin{1}, 'DrawTexture')
            varval = strrep(varargin{3}, '.texture', '.monitortexture');
            cmdParts{cmdIdx} = sprintf('additionalinfo_udp{1}=%s;', varval);
            cmdIdx = cmdIdx + 1;
        end

        % Handle output variables
        if nargout > 0
            outParts = cell(nargout, 1);
            for i = 1:nargout
                outParts{i} = sprintf('outs_udp{%d}=''a%d'';', i, i);
            end
            cmdParts{cmdIdx} = strjoin(outParts, '');
            cmdIdx = cmdIdx + 1;
        end

        % Add delimiter
        cmdParts{cmdIdx} = sprintf('args_udp{%d}=''endcommand'';', mh.lastcommand);
        mh.lastcommand = mh.lastcommand + 1;

        % Combine all parts efficiently
        mh.graphicscommandbuffer = [mh.graphicscommandbuffer, strjoin(cmdParts(1:cmdIdx), '')];

        % Handle output retrieval
        if nargout > 0
            commands = readline(mh.graphicsport);
            eval(commands);
            varargout = cell(nargout, 1);
            for i = 1:nargout
                varargout{i} = eval(['a' num2str(i)]);
            end
        end
    else
        % Clear buffer more efficiently
        writeline(mh.graphicsport, 'executegr.functionsbuffer=[];', '0.0.0.0', 2021);
    end
end

if strcmpi(varargin{1}, 'sendtogr') && ~isempty(mh.graphicscommandbuffer)
    if mh.commandID == 0
        mh.commandID = getsecs;
    end

    % Send state name once
    mh.evalgraphics(['gr.activestatename =' '''' mh.activestatename '''' ';']);
    writeline(mh.graphicsport, mh.activestatename, '0.0.0.0', 2023);

    % Send commands in one batch
    writeline(mh.graphicsport, [mh.graphicscommandbuffer, ';commandID_udp=', num2str(mh.commandID), ';'], '0.0.0.0', 2021);

    % Reset state
    mh.lastsenttime = getsecs;
    mh.graphicscommandbuffer = '';
    mh.lastcommand = 1;
    mh.holdbuffer = 0;
    mh.commandID = 0;
end
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