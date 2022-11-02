function [xmouse, ymouse, t]=mousepos(window,s)
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

[xmouse, ymouse] = GetMouse(window);
xmouse = min(xmouse, screenXpixels);
ymouse = min(ymouse, screenYpixels);

t=GetSecs-s;
end