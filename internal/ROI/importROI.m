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
      if(refExperiment.width ~= newExperiment.width || refExperiment.height ~= newExperiment.height)
        logMsg(sprintf('Experiments differ in image size (%dx%d vs %dx%d). I will do my best to accomodate', refExperiment.width, refExperiment.height, newExperiment.width, newExperiment.height), 'w');
        tmpROI = ROI;
        fullInvalid = 0;
        invalidROI = [];
        for it2 = 1:length(tmpROI)
          px = tmpROI{it2}.pixels;
          [r, c] = ind2sub(size(refExperiment.avgImg),  px);
          invalid = find(r > newExperiment.height | c > newExperiment.width);
          fullInvalid = fullInvalid + length(invalid);
          if(length(invalid) == length(r))
            invalidROI = [invalidROI; it2];
          else
            if(~isempty(invalid))
              r(invalid) = [];
              c(invalid) = [];
              if(isfield(tmpROI{it2}, 'weights'))
                tmpROI{it2}.weights(invalid) = [];
              end
            end
            newpx = sub2ind(size(newExperiment.avgImg), r, c);
            tmpROI{it2}.pixels = newpx;
            tmpROI{it2}.center = [mean(c), mean(r)];
            tmpROI{it2}.maxDistance = max(sqrt((tmpROI{it2}.center(1)-c).^2+(tmpROI{it2}.center(2)-r).^2));
          end
        end
        tmpROI(invalidROI) = [];
        newExperiment.ROI = tmpROI;
        logMsg(sprintf('Had to remove %d pixels from the ROI list', fullInvalid), 'w');
      else
        newExperiment.ROI = ROI;
      end
      
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
