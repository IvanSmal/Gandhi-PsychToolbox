function mh=makeparams(mh)
% Set your intervals
mh.addint('maxtime',20)
mh.addint('iti',5)
mh.addint('reward',0.4)

% Set your targets. if doing target logic inside the trial, don't forget to
% add a targ object into your trial structure

mh.addtarg('ball',...
    'position',[0,20;-20,20; 20,20],...
    'size',deg2pix([0.5 0.5],'size'),...
    'color', [0 1 0],...
    'shape','circle', ...
    'speed',20,...
    'direction',270,...
    'degreestype','cart')

mh.addtarg('ball2',...
    'position',[0,20;-20,20; 20,20],...
    'size',deg2pix([0.5 0.5],'size'),...
    'color', [0 1 0],...
    'shape','circle', ...
    'speed',[20; 10; 40],...
    'direction',[280;260;230;310],...
    'degreestype','cart')

mh.addtarg('paddle',...
    'position',[0 0],...
    'size',[0 0 177 16],...
    'custompath_x', 'test(mh)',...
    'custompath_y', '700',...
    'degreestype','cart')

%% add walls
mh.addtarg('l_wall',...
    'position',[180,30],...
    'size',[0 0 16 700],...
    'color', [0 1 1],...
    'shape','square')

mh.addtarg('r_wall',...
    'position',[0,30],...
    'size',[0 0 16 700],...
    'color', [0 1 1],...
    'shape','square')

mh.addtarg('t_wall',...
    'position',[90,25],...
    'size',[0 0 700 16],...
    'color', [0 1 1],...
    'shape','square')

mh.addtarg('failwall',...
    'position',[-90,25],...
    'size',[0 0 700 16],...
    'color', [0 1 1],...
    'shape','square')
%% params for normal tasks
mh.addint('T0_reach',1)
mh.addint('T0_hold',2)
mh.addint('T1_reach',5)
mh.addint('T1_hold',2)

% get a picture if you like
image1={imread("assets/Texture1.jpg")};
imsizetemp=size(image1{1});
squareImSize=[0 0 imsizetemp(2)/4 imsizetemp(1)/4];

% get a movie if you like
% mh.WaitForGraphics %checking if this function breaks here
% mh.graphicssent=1;
% mh.evalgraphics('disp(''sending movie'')')
% moviepath=fullfile(pwd, 'assets', 'movie.mp4');
% mh.Screen('OpenMovie',mh,moviepath,'set','''gr.movie''');
% mh.evalgraphics('disp(''movie sent'')')
% mh.WaitForGraphics

disp('sent_movie')
% Set your targets. if doing target logic inside the trial, don't forget to
% add a targ object into your trial structure


theta=(0:45:315)';
r=repmat(10,length(theta),1);


mh.addtarg('T0',...
    'position',[theta r;0 0],...
    'size',deg2pix([0.5 0.5],'size'),...
    'color', [0 255 0],...
    'shape','circle')

mh.addtarg('T1',...
    'position',[theta,r],...
    'size',[50 50])

mh.addtarg('T0_moving',...
    'position',[0 0],...
    'speed',10,...
    'direction',(0:45:360)',...
    'color', [0 255 0],...
    'image', './assets/Texture1.jpg', ...
    'size',squareImSize);

mh.addtarg('T1_moving',...
    'position',[0 0],...
    'custompath_x', '(x)+(sin(t)*50)',...
    'custompath_y', '(y)+(cos(t)*50)');
end