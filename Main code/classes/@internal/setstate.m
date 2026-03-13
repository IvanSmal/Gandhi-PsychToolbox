function setstate(mh, name, count)
if ~isfield(mh.trial.state,name)
    mh.trial.state.(name).count=0;
end
if nargin < 3
    count=mh.trial.state.(name).count+1;
    mh.trial.state.(name).count=count;
end

mh.trial.state.(name).time(count)=getsecs;

if ~strcmp(mh.activestatename,name)
    mh.activestatetime = mh.trial.state.(name).time(end);
    mh.activestatename = name;
end
%send to datastream:
name_hex=dec2hex(name); %convert to hex

for i=1:size(name_hex,1); xippmex('digout', 5, hex2dec(name_hex(i,:)));end%convert hex to numbers and send as digital stamp

writeline(mh.graphicsport, name, 'localhost', 2024 )
disp(name)
end