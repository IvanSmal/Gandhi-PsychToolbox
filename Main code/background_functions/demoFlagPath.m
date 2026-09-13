function p = demoFlagPath()
%DEMOFLAGPATH File whose existence means "demo mode" (simulated xippmex).
%   Created by enableDemoXippmex, removed by disableDemoXippmex. Cross-process:
%   MonkeyHost sets it when the operator chooses demo mode, and GraphicsHandler /
%   TrellisScope check it at startup so every process uses the mock xippmex.
if isfolder('/dev/shm')
    p = '/dev/shm/gandhi_demo_mode';
else
    p = fullfile(tempdir, 'gandhi_demo_mode');
end
end
