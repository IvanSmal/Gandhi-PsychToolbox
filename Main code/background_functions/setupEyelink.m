function out = setupEyelink(app,first)
%SETUPEYELINK Summary of this function goes here
%   Detailed explanation goes here
% if first
%     try
%     Eyelink('SetAddress','192.168.42.3');
%     Eyelink('initialize');
%     catch
%         insToTxtbox(app,'Can''t connect to EyeLink. Is it on?')
%     end
% end
% try
% status=Eyelink('CurrentMode');
% if status ~=4
%     app.EyeLinkLamp.Color=[1,1,0];
%     if app.checkEyeLink
%     insToTxtbox(app,'Eyelink not in "record" mode')
%     app.checkEyeLink=0;
%     end
% elseif status ==4
%     app.checkEyeLink=1;
%     app.EyeLinkLamp.Color=[0,1,0];
% end
% catch
    app.EyeLinkLamp.Color=[1,0,0];
%     try
%         Eyelink('SetAddress','192.168.42.3');
%     end
%     try
%         Eyelink('initialize');
%     end
% end
end


