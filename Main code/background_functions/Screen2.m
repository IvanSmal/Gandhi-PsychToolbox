function varargout=Screen2(a,mh,varargin)
mh.rtport.UserData.a=a;
mh.rtport.UserData.varargin=varargin;

udpstring=['a=' string(a) ';' 'vars=' string(varargin)];

writeline(send,udpstring,'0.0.0.0',2021)

end
