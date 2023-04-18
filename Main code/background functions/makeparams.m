function mh=makeparams(mh)
% Set your intervals
mh.addint('T0_reach',1)
mh.addint('T0_hold',0.2)
mh.addint('T1_reach',5)
mh.addint('T1_hold',2)
mh.addint('iti',0.5)
mh.addint('reward',0.4)

% get a picture if you like
image1={imread("assets\Texture1.jpg")};
imsizetemp=size(image1{1});
squareImSize=[0 0 imsizetemp(2)/4 imsizetemp(1)/4];

%get a movie if you like
% moviepath=fullfile(pwd, 'assets', 'movie.mp4');
% mh.getmovie(moviepath)

% Set your targets. if doing target logic inside the trial, don't forget to
% add a targ object into your trial structure


theta=(0:45:315)';
r=repmat(10,length(theta),1);


mh.addtarg('T0',...
    'position',[theta r;0 0],...
    'size',deg2pix([0.5 0.5],'size'),...
    'color', [0 1 0],...
    'shape','circle')

mh.addtarg('T1',...
    'position',[theta,r],...
    'size',[50 50])

mh.addtarg('T0_moving',...
    'position',[0 0],...
    'speed',10,...
    'direction',(0:45:360)',...
    'color', [0 1 0],...
    'image', image1, ...
    'size',squareImSize);

mh.addtarg('T1_moving',...
    'position',[0 0],...
    'custompath_x', '(x)+(sin(t)*50)',...
    'custompath_y', '(y)+(cos(t)*50)');

end