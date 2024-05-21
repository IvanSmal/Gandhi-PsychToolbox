function out = checkint(mh, state, int)
out = strcmp(state, mh.activestatename) && (getsecs < mh.activestatetime + mh.trialint(int));
end