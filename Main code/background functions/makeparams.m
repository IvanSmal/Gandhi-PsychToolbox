function mh=makeparams(mh)
% Set your intervals
mh.addint('T0_reach',3)
mh.addint('T0_hold',2)
mh.addint('T1_reach',5)
mh.addint('T1_hold',2)
mh.addint('iti',2)
mh.addint('reward',0.2)

% get a picture if you like
image1={imread("assets\Texture1.jpg")};
imsizetemp=size(image1{1});
squareImSize=[0 0 imsizetemp(2)/4 imsizetemp(1)/4];

%get a movie if you like
% moviepath=fullfile(pwd, 'assets', 'movie.mp4');
% mh.getmovie(moviepath)

% Set your targets. if doing target logic inside the trial, don't forget to
% add a targ object into your trial structure
center=[mh.xCenter,mh.yCenter];
mh.addtarg('T0',...
    'position',deg2pix([0,10;90,10;180,10;270,10],'pol'),...
    'color', [0 1 0],...
    'shape','circle')

theta=[0:45:360]';
r=repmat(5,length(theta),1);

mh.addtarg('T1',...
    'position',deg2pix([theta,r],'polar'),...
    'size',[50 50])

mh.addtarg('T0_moving',...
    'position',center,...
    'speed',100,...
    'direction',[0:45:360]',...
    'color', [0 1 0],...
    'image', image1, ...
    'size',squareImSize);

mh.addtarg('T1_moving',...
    'position',center,...
    'custompath_x', '(x)+(sin(t)*500)',...
    'custompath_y', '(y)+(cos(t)*500)');

end