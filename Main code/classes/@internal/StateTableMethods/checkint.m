function out = checkint(mh, state, int)
out = strcmp(state, mh.activestatename) && (getsecs < mh.activestatetime + mh.trialint(int));
if out~=1
    display(mh.activestatetime + mh.trialint(int)-getsecs)
end
end