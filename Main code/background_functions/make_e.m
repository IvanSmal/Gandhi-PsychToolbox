function expt = make_e(app)
%MAKE_E Build an experiment object from the current GUI field values.
expt=experiment;
expt.subject_name = app.SubjectNameEditField.Value;
expt.DataDir = app.Dir.Value;
expt.TrellisDir=app.TrellisDir.Value;
expt.parameter_file=app.ParameterFile.Value;
end

