function importExperimentFromWorkspace(~, ~, ~)
% EXPERIMENTTOWORKSPACE - Netcal Plugin
  answer = questdlg('Are you sure? Current experiment will be overriden', 'Import experiment from workspace', 'Yes', 'No', 'Cancel', 'Cancel');
  switch answer
    case 'Yes'
      experiment = evalin('base', 'experiment');
      saveExperiment(experiment, 'verbose', true);
      logMsg('Experiment successfully exported to MATLAB workspace');
    case 'No'
      return;
    case 'Cancel'
      return;
    otherwise
      return;
  end
end
