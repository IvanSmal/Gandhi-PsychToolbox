function addtarg(mh,name,varargin)
outcells=[{'name'}, {name}, varargin(:)'];
mh.targets.(name)=target(outcells{:});
end