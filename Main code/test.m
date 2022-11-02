function out=test(varargin)
    for i=1:length(varargin)
        out.(inputname(i))=varargin{:};
    end
end
