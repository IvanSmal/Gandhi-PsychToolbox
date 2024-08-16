function out=getint(mh,name)
out=mh.intervals.(name).getint(1);
mh.trial.insert('intervals',out);
end