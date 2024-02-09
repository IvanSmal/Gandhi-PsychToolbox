% Set your intervals
mh.addint('T0_Reach',5)
mh.addint('T0_Hold',1)

mh.addint('delay',[0.3:0.1:1]);

mh.addint('T1_Reach',2)
mh.addint('T1_Hold',0.5)
mh.addint('T1_Hold_moving',1)

mh.addint('iti',1)
mh.addint('reward',0.5)

% Set your targets. if doing target logic inside the trial, don't forget to
% add a targ object into your trial structure

theta=0:45:315;
allpos=[theta' repmat(10,length(theta),1);theta' repmat(20,length(theta),1);];
mh.addtarg('T_Calibrate',...
    'position',allpos,... %position is in theta rho format
    'size',deg2pix([0.3 0.3],'size'),...
    'window', 5,...
    'color', [1 1 1],...
    'shape','circle',...
    'degreestype','polar');

mh.addtarg('T0',...
    'position',[0,0],... 
    'size',deg2pix([0.3 0.3],'size'),...
    'window', 5,...
    'color', [1 1 1],...
    'shape','circle',...
    'degreestype','polar');

mh.addtarg('T1_Stationary',...
    'position',[zeros(11,1),(10:20)'],...
    'size',deg2pix([0.3 0.3],'size'),...
    'window', 10,...
    'color', [1 1 1],...
    'shape','circle',...
    'degreestype','polar')

mh.addtarg('T1_Moving_out',...
    'position',[0,2],...
    'size',deg2pix([0.3 0.3],'size'),...
    'window', 15,...
    'color', [1 1 1],...
    'shape','circle', ...
    'speed',15,... %deg/s
    'direction',90,...
    'degreestype','polar')

mh.addtarg('T1_Moving_in',...
    'position',[0,28],...
    'size',deg2pix([0.3 0.3],'size'),...
    'window', 15,...
    'color', [1 1 1],...
    'shape','circle', ...
    'speed',15,... %deg/s
    'direction',270,...
    'degreestype','polar')
