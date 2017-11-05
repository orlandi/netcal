function projexp = exportFluorescenceFeatures(projexp, varargin)
% EXPORTFLUORESCENCEFEATURES exports fluorescence features
%
% USAGE:
%    projexp = exportFluorescenceFeatures(projexp, varargin)
%
% INPUT arguments:
%    projexp - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportBaseOptions
%
% OUTPUT arguments:
%    projexp - project experiment structure
%
% EXAMPLE:
%    experiment = exportFluorescenceFeatures(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export fluorescence features
% parentGroups: fluorescence: group classification: feature-based: exports
% optionsClass: exportBaseOptions
% requiredFields: traceFeatures, traceFeaturesNames, ROI, folder, name

[params, var] = processFunctionStartup(exportBaseOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting fluorescence features', true);
%--------------------------------------------------------------------------

% Check if its a project or an experiment

if(isfield(projexp, 'saveFile'))
  [~, ~, fpc] = fileparts(projexp.saveFile);
  if(strcmpi(fpc, '.exp'))
    mode = 'experiment';
    experiment = projexp;
  else
    mode = 'project';
    project = projexp;
  end
else
  mode = 'project';
  project = projexp;
end


switch mode
  case 'experiment'
    if(~exist(experiment.folder, 'dir'))
      mkdir(experiment.folder);
    end
    dataFolder = [experiment.folder 'data' filesep];
    if(~exist(dataFolder, 'dir'))
      mkdir(dataFolder);
    end
    exportData = getExportData(experiment);
    if(strcmp(params.exportType, 'csv'))
      outputFile = [dataFolder, experiment.name, '_fluorescenceFeaturesData.csv'];
      fID = fopen(outputFile, 'W');
      fmt = repmat('%s, ',1, length(experiment.traceFeaturesNames));
      fmt = [fmt(1:end-2) '\n'];
      fprintf(fID, fmt, experiment.traceFeaturesNames{:});
      
      fmt = repmat('%.5f, ',1, size(exportData,2));
      fmt = [fmt(1:end-2) '\n'];
      for it = 1:size(exportData,1)
        fprintf(fID, fmt,exportData(it,:));
      end
      fclose(fID);
    else
      outputFile = [dataFolder, experiment.name, '_fluorescenceFeaturesData.' params.exportType];
      %save(outputFile, 'exportData', '-mat');
      exportDataCallback([], [], [], [], ...
                     exportData, ...
                     experiment.traceFeaturesNames, ...
                     experiment.name, [], ...
                     outputFile);
    end

  case 'project'
    checkedExperiments = find(project.checkedExperiments);
    if(isempty(checkedExperiments))
      logMsg('No checked experiments found', 'e');
      return;
    end
    
    if(~exist(project.folder, 'dir'))
      mkdir(project.folder);
    end
    dataFolder = [project.folder 'data' filesep];
    if(~exist(dataFolder, 'dir'))
      mkdir(dataFolder);
    end
    if(strcmp(params.exportType, 'csv'))
      outputFile = [dataFolder, project.name, '_fluorescenceFeaturesData.csv'];
      fID = fopen(outputFile, 'W');
    else
      outputFile = [dataFolder, project.name, '_fluorescenceFeaturesData.' params.exportType];
    end
    for i = 1:length(checkedExperiments)
      experimentName = project.experiments{checkedExperiments(i)};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      exportData = getExportData(experiment);
      if(strcmp(params.exportType, 'csv'))
        if(i == 1)
          fullNames = experiment.traceFeaturesNames;
          fullNames{end+1} = 'experiment name';
          fmt = repmat('%s, ',1, length(fullNames));
          fmt = [fmt(1:end-2) '\n'];
          fprintf(fID, fmt, fullNames{:});
        end
        fmt=[repmat('%.5f, ',1,size(exportData,2)) '%s' '\n'];
        for it = 1:size(exportData,1)
          fprintf(fID, fmt,exportData(it,:), experiment.name);
        end
      else
        exportDataCallback([], [], [], [], ...
                     exportData, ...
                     experiment.traceFeaturesNames, ...
                     experimentName, [], ...
                     outputFile);
      end
    end
    if(strcmp(params.exportType, 'csv'))
      fclose(fID);
    end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  function exportData = getExportData(experiment)
    experiment = checkGroups(experiment);
    if(isfield(experiment, 'features') && (~isfield(experiment, 'traceFeatures') || ~isfield(experiment, 'traceFeaturesNames')))
      logMsg(sprintf('Experiment %s contains an old definition of features. Please extract them again', experiment.name), 'w');
      exportData = [];
      return;
    elseif(~isfield(experiment, 'traceFeatures') || ~isfield(experiment, 'traceFeaturesNames'))
      logMsg(sprintf('No features found in experiment %s', experiment.name), 'w');
      exportData = [];
      return;
    end
    exportData = experiment.traceFeatures;
  end
end


