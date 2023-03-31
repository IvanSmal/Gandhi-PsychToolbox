function out = xippmex(varargin)
% for debugging purposes we are re-routing all xippmex calls here. This
% function will return garbage, but will allow the code to proceed without
% needing the scout system

if nargin == 0
    out =1;
elseif strcmp(varargin{1},'digout')
    out=varargin{3};
    disp(out)
elseif strcmp(varargin{1},'elec')
    out=1:1500;
elseif strcmp(varargin{1},'cont')
    if varargin{2}==3
        [temp,~]=GetMouse;
        out=repmat(temp,1,varargin{3});
    elseif varargin{2}==4
        [~,temp]=GetMouse;
        out=repmat(temp,1,varargin{3});
    else
        out=1:1500;
    end
else
    out=randi(100);
end
end

