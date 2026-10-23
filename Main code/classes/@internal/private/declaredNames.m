function out = declaredNames(container)
%DECLAREDNAMES Comma-separated list of the names a struct container holds.
%   Used by the accessors to make "not declared" errors self-diagnosing:
%   knowing what the loaded parameter file *does* provide is usually enough
%   to spot that the wrong parameter file is loaded. Tolerates the empty
%   ([]) state a container has before anything has been added to it.
if isstruct(container)
    names = fieldnames(container);
else
    names = {};
end
if isempty(names)
    out = '(none)';
else
    out = strjoin(names', ', ');
end
end
