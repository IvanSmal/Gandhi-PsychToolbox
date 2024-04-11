function stoptrial(mh,success)
mh.setstate('stop')
% if mh.checkstate('stop')
%     mh.Screen('FillOval', 'windowPtr', [0 0 0], [0 0 10 10]);
%     mh.graphicssent=0;
%     while mh.graphicssent==0
%         str=('writeline(graphicsport,''mh.graphicssent=1;'',''0.0.0.0'',2020);Screen(''Flip'',gr.window_main);Screen(''Flip'',gr.window_monitor);gr.trialstarted=0;');
%         mh.evalgraphics(str);
%         com=readline(mh.graphicsport);
%         try %this is a dirty way to make sure 'com' is evaluatable
%             eval(com);
%         catch
%         end
%     end
% end
flush(mh.graphicsport);
mh.graphicssent=1;
mh.trialstarted = 0;
mh.runtrial = 0;
mh.trial.success=success;
if success
    mh.sum_success=mh.sum_success+1;
end
mh.Screen('sendtogr')
for i=1:100
    mh.evalgraphics('gr.trialstarted=0;');
    pause(0.0001)
end
end