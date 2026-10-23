function [code, names, codes] = stateEventCode(name)
%STATEEVENTCODE Stable per-session integer event code for a state name.
%   code = stateEventCode(name) returns a unique integer for the state NAME,
%   assigning the next free code the first time a name is seen this session.
%   [~, names, codes] = stateEventCode() returns the whole lookup table
%   (names{i} <-> codes(i)) so it can be saved into trial.data.
%
%   setstate sends the code as ONE parallel-port marker: xippmex('digout',5,code).
%   Each digout creates a NIP-timestamped digital event (digin reason bit 32)
%   that Trellis records, so state onsets are timestamped in the neural data, and
%   the saved table decodes each recorded code back to a state name offline.
%
%   Codes start at 100 (1-99 left free for future trial-control markers). The
%   registry is per MATLAB session and resets on restart -- which is exactly why
%   the full table is saved with every trial's data.
    persistent M
    if isempty(M)
        M = containers.Map('KeyType', 'char', 'ValueType', 'double');
    end
    code = [];
    if nargin >= 1 && ~isempty(name)
        name = char(name);
        if ~isKey(M, name)
            M(name) = 100 + double(M.Count);   % next free code
        end
        code = M(name);
    end
    if nargout >= 2
        names = M.keys;
        codes = cell2mat(M.values);
        if isempty(codes), codes = []; end
    end
end
