function out=trialtarg(obj,name,arg,varargin)
out=obj.trial.targets.(name).(arg)(obj,varargin{:});
end