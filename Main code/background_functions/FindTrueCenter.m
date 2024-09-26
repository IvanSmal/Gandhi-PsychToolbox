function FindTrueCenter
%FINDTRUECENTER Summary of this function goes here
%   Detailed explanation goes here


Screen('Preference', 'SkipSyncTests', 2);
Priority(2);

% Clear the workspace and the screen
sca;
close all;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% Get the screen numbers
in.screens = Screen('Screens');

if in.screens < 1
    errordlg('Only found 1 screen')
    return
else
    screenNum=max(in.screens);
end

% Define black and white
black = BlackIndex(screenNum);

% Open an on screen window
[window_main, windowRect] = PsychImaging('OpenWindow', screenNum, black);

[xCenter, yCenter] = RectCenter(windowRect);
pos=[xCenter-2 yCenter-2 xCenter+2 yCenter+2];
kCode=pi;

while find(kCode,1)~=13
    [~,~,kCode]=KbCheck;
    if find(kCode,1)==38
        pos=pos+[0 -1 0 -1];
    elseif find(kCode,1)==40
        pos=pos+[0 1 0 1];
    elseif find(kCode,1)==37
        pos=pos+[-1 0 -1 0];
    elseif find(kCode,1)==39
        pos=pos+[1 0 1 0];
    end

    Screen('FillRect',window_main,[1 1 1],pos)
    Screen('Flip',window_main);

    if isempty(find(kCode,1))
        kCode(end)=1;
    end
end

center=[pos(1)+2 pos(2)+2];

disp(['The new center is: ' num2str(center)])
a=input('Save the new center? (y/n): ','s');

if a=='y'
    ini=IniConfig();
    ini.ReadFile('inis/ScreenParams.ini');
    ini.SetValues('for deg2pix','true center',{num2str(center)});
    ini.WriteFile('inis/ScreenParams.ini');
    disp('New center position recorded')
else
    disp('New center not saved. You can manually add it to the ini file. Be careful please.')
end

sca;
close all;
end

