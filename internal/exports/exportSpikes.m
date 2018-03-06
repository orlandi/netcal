function projexp = exportSpikes(projexp, varargin)
% EXPORTSPIKES exports spike data
%
% USAGE:
%    projexp = exportBurstStatistics(projexp, varargin)
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
%    experiment = exportBurstStatistics(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export spikes
% parentGroups: spikes: exports
% optionsClass: exportSpikesOptions
% requiredFields: spikes, ROI, folder, name

[params, var] = processFunctionStartup(exportSpikesOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting spikes', true);
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

colNames = {'neuron index'};
if(params.includeSimplifiedROIorder)
  colNames{end+1} = 'neuron index simplified';
end

switch params.timeUnits
  case 'seconds'
    colNames{end+1} = 'time (s)';
    exportFormat = '%d, %.5f';
  case 'milliseconds'
    colNames{end+1} = 'time (ms)';
    exportFormat = '%d, %.5f';
  case 'frames'
    colNames{end+1} = 'frame';
    exportFormat = '%d, %d';
end
if(params.includeSimplifiedROIorder)
  exportFormat = ['%d, ' exportFormat];
end

switch mode
  case 'experiment'
    switch params.exportFolder
      case 'experiment'
        mainFolder = experiment.folder;
      case 'project'
        mainFolder = [experiment.folder '..' filesep];
    end
    if(~exist(mainFolder, 'dir'))
      mkdir(mainFolder);
    end
    dataFolder = [mainFolder 'exports' filesep];
    if(~exist(dataFolder, 'dir'))
      mkdir(dataFolder);
    end
    exportData = getExportData(experiment);
    if(strcmp(params.exportType, 'csv'))
      outputFile = [dataFolder, experiment.name, '_spikesData.csv'];
      fID = fopen(outputFile, 'W');
      fmt = repmat('%s, ',1, length(colNames));
      fmt = [fmt(1:end-2) '\n'];
      fprintf(fID, fmt, colNames{:});
      
      fmt = exportFormat;
      fmt = [fmt '\n'];
      for i = 1:size(exportData,1)
        fprintf(fID, fmt,exportData(i,:));
      end
      fclose(fID);
    else
      outputFile = [dataFolder, experiment.name, '_spikesData.' params.exportType];
      %save(outputFile, 'exportData', '-mat');
      exportDataCallback([], [], [], [], ...
                     exportData, ...
                     colNames, ...
                     experiment.name, [], ...
                     outputFile);
    end

  case 'project'
    checkedExperiments = find(project.checkedExperiments);
    if(isempty(checkedExperiments))
      logMsg('No checked experiments found', 'e');
      return;
    end
    
    % Create the exports folder
    mainFolder = project.folder;
    if(~exist(mainFolder, 'dir'))
      mkdir(mainFolder);
    end
    dataFolder = [mainFolder 'exports' filesep];
    if(~exist(dataFolder, 'dir'))
      mkdir(dataFolder);
    end
    if(strcmp(params.exportType, 'csv'))
      outputFile = [dataFolder, project.name, '_spikesData.csv'];
      fID = fopen(outputFile, 'W');
    else
      outputFile = [dataFolder, project.name, '_spikesData.' params.exportType];
    end
    for i = 1:length(checkedExperiments)
      experimentName = project.experiments{checkedExperiments(i)};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      exportData = getExportData(experiment);
      if(strcmp(params.exportType, 'csv'))
        if(i == 1)
          fullNames = colNames;
          fullNames{end+1} = 'experiment name';
          fmt = repmat('%s, ',1, length(fullNames));
          fmt = [fmt(1:end-2) '\n'];
          fprintf(fID, fmt, fullNames{:});
        end
        fmt=[exportFormat ', %s' '\n'];
        for j = 1:size(exportData,1)
          fprintf(fID, fmt,exportData(j,:), experiment.name);
        end
      else
        exportDataCallback([], [], [], [], ...
                     exportData, ...
                     colNames, ...
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
  exportData = [];
  if(~isfield(experiment, 'spikes'))
    logMsg(sprintf('Spikes not found in experiment %s', experiment.name), 'w');
    return;
  end
  
  try
    subpop = [];
    if(iscell(params.subpopulation))
      subpop = params.subpopulation{1};
    else
      subpop = params.subpopulation;
    end
    members = getExperimentGroupMembers(experiment, subpop);
    ROIid = getROIid(experiment.ROI);

    N = [];
    T = [];
    if(params.includeSimplifiedROIorder)
      No = [];
    end
    for it = 1:length(members)
      if(~all(isnan(experiment.spikes{members(it)}')))
        T = [T; experiment.spikes{members(it)}(:)];
        N = [N; ones(size(experiment.spikes{members(it)}(:)))*ROIid(members(it))];
        if(params.includeSimplifiedROIorder)
          No = [No; ones(size(experiment.spikes{members(it)}(:)))*it];
        end
      end
    end
    switch params.timeUnits
      case 'seconds'
      case 'milliseconds'
        T = T*1000;
      case 'frames'
        T = round(T*experiment.fps);
    end
    if(params.includeSimplifiedROIorder)
      mat = double([N, T, No]);
    else
      mat = double([N, T]);
    end
    switch params.exportOrder
      case 'time'
        mat = sortrows(mat, 2);
      case'ROI'
        mat = sortrows(mat, 1);
    end
    if(params.includeSimplifiedROIorder)
      mat = mat(:, [1 3 2]);
    end
  catch ME
    logMsg(sprintf('Something was wrong getting loading spikes from %s in experiment %s', subpop, experiment.name), 'e');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    return;
  end
  % Change for each statistic
  exportData = mat;
  if(~isempty(params.subset))
    valid = (exportData(:,2) >= params.subset(1) & exportData(:,2) <= params.subset(2));
    exportData = exportData(valid, :);
  end
end
end
