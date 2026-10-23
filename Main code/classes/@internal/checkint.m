function out = checkint(mh, state, int)
out = strcmp(state, mh.activestatename) && (GetSecs < mh.activestatetime + mh.trialint(int));
end