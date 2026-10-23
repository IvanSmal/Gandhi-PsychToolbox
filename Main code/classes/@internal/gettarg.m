function out=gettarg(mh,targname)
%GETTARG Draw this trial's instance of a target declared in the parameter file.
%   Errors by name if the loaded parameter file never declared it; see GETINT.
if ~isfield(mh.targets, targname)
    error('gettarg:undeclared', ...
        ['target "%s" is not declared by the loaded parameter file.\n' ...
         '    Declared targets: %s\n' ...
         '    Load the parameter file this task expects, or add ' ...
         'mh.addtarg(''%s'', ...) to the one you loaded.'], ...
        targname, declaredNames(mh.targets), targname);
end
temptarg=mh.targets.(targname);
tempprops=properties(temptarg);
for i=1:numel(tempprops)
    numvals=size(temptarg.(tempprops{i}),1);
    if numvals>0
        randidx=randi(numvals);
        temptarg.(tempprops{i})=temptarg.(tempprops{i})(randidx,:);
    end
end
if ~isempty(temptarg.image)
    %% create a set of commands to send to graphics handler
    Str1=strcat('gr.target.',targname,'.image=','imread(''',temptarg.image, ''');');
    Str2=strcat('gr.target.',targname,'.texture=');
    Str3=strcat('Screen(''MakeTexture'',gr.window_main,gr.target.',...
        targname,'.image);');
    Str4=strcat('gr.target.',targname,'.monitortexture=');
    Str5=strcat('Screen(''MakeTexture'',gr.window_monitor,gr.target.',...
        targname,'.image);');
    MasterString=strcat(Str1,Str2,Str3,Str4,Str5);
    mh.evalgraphics(MasterString)
end
mh.trial.insert('targets',temptarg);
out=temptarg;
end
