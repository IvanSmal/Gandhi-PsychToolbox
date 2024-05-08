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

mh.evalgraphics(['gr.activestatename =' '''' mh.activestatename '''' ';']);

end