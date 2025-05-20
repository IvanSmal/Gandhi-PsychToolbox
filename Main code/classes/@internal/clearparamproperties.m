function mh=clearparamproperties(mh)
PARAMPROPERTIES = {'intervals', 'targets'};
for i=1:length(PARAMPROPERTIES)
    mh.(PARAMPROPERTIES{i})=[];
end
end

