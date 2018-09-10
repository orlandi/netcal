function project = importROI(project, varargin)
% IMPORTROI Imports external ROI list (either from another experiment or
% an external file)
%
% USAGE:
%   project = importROI(project, options)
%
% INPUT arguments:
%   project - structure containing a project
%
% INPUT optional arguments:
%   options - object from class importROIoptions
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
% OUTPUT arguments:
%   project - structure containing an experiment
%
% EXAMPLE:
%   project = importROI(project, importROIoptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also importROIoptions

% PROJECT PIPELINE
% name: import ROI
% parentGroups: ROI: imports
% optionsClass: importROIoptions
% requiredFields: fps, numFrames, width, height
% producedFields: ROI
  
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(importROIoptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Importing ROI');
%--------------------------------------------------------------------------

switch params.origin 
  case 'experiment'
    %params.experiment
    experimentFile = [project.folderFiles params.experiment '.exp'];
    refExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
  
    if(~isfield(refExperiment, 'ROI') || isempty(refExperiment.ROI))
      logMsg('No ROI found', 'e');
      barCleanup(params);
      return;
    end
    ROI = refExperiment.ROI;
    logMsg([num2str(length(ROI)) ' ROI imported']);
    valid = find(project.checkedExperiments);
    for it = 1:length(valid)
      if(params.pbar > 0)
        ncbar.setCurrentBarName(sprintf('Updating ROI on experiment: %s', project.experiments{valid(it)}));
        ncbar.update(it/length(valid));
      end
      experimentFile = [project.folderFiles project.experiments{valid(it)} '.exp'];
      newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      newExperiment.ROI = ROI;
      if(params.verbose || params.pbar > 0)
        logMsg(sprintf('%d  ROI assigned to experiment %s',length(newExperiment.ROI), newExperiment.name));
      end
      saveExperiment(newExperiment, 'pbar', 0, 'verbose', false);
    end
    
  case 'external file'
    if(~exist(params.file, 'file')) %#ok<BDSCI,OR2,BDLGI>
        logMsg('Invalid ROI file', 'e');
        barCleanup(params);
        return;
    end
    valid = find(project.checkedExperiments);
    for it = 1:length(valid)
      if(params.pbar > 0)
        ncbar.setCurrentBarName(sprintf('Updating ROI on experiment: %s', project.experiments{valid(it)}));
        ncbar.update(it/length(valid));
      end
      experimentFile = [project.folderFiles project.experiments{valid(it)} '.exp'];
      newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);

      newExperiment.ROI = loadROI(newExperiment, params.file, 'overwriteMode', 'rawNew', 'verbose', false);
      if(params.verbose || params.pbar > 0)
        logMsg(sprintf('%d  ROI imported to experiment %s',length(newExperiment.ROI), newExperiment.name));
      end
      saveExperiment(newExperiment, 'pbar', 0, 'verbose', false);
    end
end


%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
end
