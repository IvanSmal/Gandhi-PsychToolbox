function addint(mh,name,dur, prob)
if nargin ==3
    mh.intervals.(name)=interval(name, dur);
else
    mh.intervals.(name)=interval(name, dur, prob);
end
end