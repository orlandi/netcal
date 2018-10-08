function experimentToWorkspace(~, ~, ~)
% EXPERIMENTTOWORKSPACE - Netcal Plugin
  
  project = getappdata(gcbf, 'project');
  experiment = loadCurrentExperiment(project);
  assignin('base', 'experiment', experiment);
  logMsg('Experiment successfully exported to MATLAB workspace');
end
