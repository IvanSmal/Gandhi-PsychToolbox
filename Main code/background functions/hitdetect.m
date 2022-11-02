function out=hitdetect(cursor,target, tolerance_window)

% find center of target
x=(target(1)+target(3))/2;
y=(target(2)+target(4))/2;

% check how far the cursor is from the centerpoint
d=hypot((cursor(1)-x),(cursor(2)-y));

if tolerance_window >=d
    out=1;
else
    out=0;
end
end