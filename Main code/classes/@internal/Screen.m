function varargout = Screen(mh,varargin)
currentcommand=jsonencode(varargin(:));
if ~strcmp(mh.cachedout,currentcommand) && ~mh.holdbuffer %check that it is not sending the same command
    mh.cachedout=currentcommand; %cache current command
    if ~matches(varargin{1},'clearbuffer','IgnoreCase',true) &&...
            ~matches(varargin{1},'sendtogr','IgnoreCase',true) %check that user is not trying to clear the UDP buffer
        str=string();
        for i=1:length(varargin)
            namecount=0;
            if matches(class(varargin{i}),'char')
                if contains(varargin{i},'gr') % if the user calls for graphics then...
                    varval=['' varargin{i} '']; % send "gr" as a call to the gr object
                else
                    varval=['''' varargin{i} '''']; % otherwise convert to interpretable string
                end
            elseif isnumeric(varargin{i}) % if it's a number, make it a string
                varval=mat2str(varargin{i});
            elseif isobject(varargin{i})
                targname=varargin{i}.name;
                pos=mh.trialtarg(targname,'getpos');
                varval=mat2str(pos);
                % mh.trial.targets.(targname).moving_position=[mh.trial.targets.(targname).moving_position; pix2deg(pos)];
                % mh.commandID=mh.trial.targets.(targname).timestamp(end);
            else %if its a variable make the name a string
                namecount=namecount+1;
                varval=['''',string(inputname(namecount)),''''];
            end
            str=str.append(['args_udp{',num2str(mh.lastcommand), '}=', varval, ';']);
            mh.lastcommand=mh.lastcommand+1;
        end

        if matches(varargin{1},'DrawTexture') %add a texture for monitor window
            varval=replace(varargin{3},'.texture','.monitortexture');
            str=str.append([ 'additionalinfo_udp{1}=', varval, ';']); %put this command into the additional option slot
        end

        if nargout>0 %if the user wants an output from psychtoolbox, it goes here
            for i=1:nargout
                str=str.append(['outs_udp{',num2str(i), '}=', '''a',num2str(i), ''';']);
            end
        end

        deliminator=['args_udp{',num2str(mh.lastcommand), '}=''endcommand'';'];
        mh.lastcommand=mh.lastcommand+1;
        mh.graphicscommandbuffer=[mh.graphicscommandbuffer, str,deliminator];

        if nargout>0 %get outs. this needs work
            commands=readline(mh.graphicsport);
            eval(commands);
            varargout=cell(nargout);
            for i=1:nargout
                varargout{i}=eval(['a' num2str(i)]);
            end
        end
    else %if user calls to clear buffer, clear buffer
        writeline(mh.graphicsport,'executegr.functionsbuffer=[];','0.0.0.0',2021)
    end
end
if matches(varargin{1},'sendtogr','IgnoreCase',true) && ~isempty(mh.graphicscommandbuffer)
    % mh.holdbuffer = 1;
    if mh.commandID==0
        mh.commandID=getsecs;
    end

    writeline(mh.graphicsport,join([[mh.graphicscommandbuffer{:}], ";commandID_udp=" ,num2str(mh.commandID), ';']),'0.0.0.0',2021); %actually send the data

    writeline(mh.graphicsport,'executegr.fliprequest=1;','0.0.0.0',2021);
    mh.graphicscommandbuffer='';
    mh.lastcommand=1;
    mh.holdbuffer = 0;
    mh.commandID=0;
    % writeline(mh.graphicsport,'executegr.functionsbuffer=[];','0.0.0.0',2021); %need to figure out how to asynch this
    % parfeval(mh.parpool,@writeline,0,mh.graphicsport,'executegr.functionsbuffer=[];','0.0.0.0',2021);

end
end