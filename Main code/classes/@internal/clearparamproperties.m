function mh=clearparamproperties(mh)
PARAMPROPERTIES = {'intervals', 'targets'};
for i=length(PARAMPROPERTIES)
    mh.(PARAMPROPERTIES{i})=[];
end
end

