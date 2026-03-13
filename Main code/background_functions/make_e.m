function e = make_e(app)
%MAKE_E Summary of this function goes here
%   Detailed explanation goes here
e=experiment;
e.subject_name = app.SubjectNameEditField.Value;
e.DataDir = app.Dir.Value;
e.TrellisDir=app.TrellisDir.Value;
e.parameter_file=app.ParameterFile.Value;
end

