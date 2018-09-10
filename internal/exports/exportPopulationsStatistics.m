function projexp = exportPopulationsStatistics(projexp, varargin)
% EXPORTPOPULATIONSSTATISTICS exports populations statistics
%
% USAGE:
%    projexp = exportPopulationsStatistics(projexp, varargin)
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
%    experiment = exportPopulationsStatistics(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: export labeled groups statistics
% parentGroups: populations: exports
% optionsClass: exportPopulationsStatisticsOptions
% requiredFields: traceBursts, folder, name

[params, var] = processFunctionStartup(exportPopulationsStatisticsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting group statistics', true);
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

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

switch mode
  case 'experiment'
    checkedExperiments = 1;
    % Create the exports folder
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
    outputFileName = [dataFolder, experiment.name, '_groups'];
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
    outputFileName = [dataFolder, 'groups'];
end  

switch params.statisticsType
  case 'absolute'
    labels = '';
end
[labelList, uniqueLabels, labelsCombinations, labelsCombinationsNames, experimentsPerCombinedLabel] = getLabelList(project);


switch params.fileType
  case 'csv'
    outputFile = [outputFileName '.csv'];
    fID = fopen(outputFile, 'W');
    % Create and write the header
    fmt = repmat('%s, ',1, length(labels));
    fmt = [fmt(1:end-2) '\n'];
    fprintf(fID, fmt, labels{:});
    
    %fmt = [repmat([params.numericFormat, ', '], 1, length(labels)-2) '%s, %d\n'];
    fmt = repmat([params.numericFormat, ', '], 1, length(labels)-2);
    %fmt = [fmt(1:end-2) '\n'];
    fmtEnd = '%s, %s, %d\n';
  case 'txt'
    outputFile = [outputFileName '.txt'];
    fID = fopen(outputFile, 'W');
    % No header
    fmt = repmat([params.numericFormat, ', '], 1, length(labels)-2);
    fmtEnd = '%s %s %d\n';
end

    
% Main loop for the export data
for itt = 1:length(checkedExperiments)
  % If it's the experiment, we already have the experiment defined
  switch mode
    case 'project'
    experimentName = project.experiments{checkedExperiments(itt)};
    experimentFile = [project.folderFiles experimentName '.exp'];
    experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
  end
  % Get ALL subgroups in case of parents
  if(strcmpi(mainGroup, 'all'))
    groupList = getExperimentGroupsNames(experiment);
  else
    groupList = getExperimentGroupsNames(experiment, mainGroup);
  end

  % Empty check
  if(isempty(groupList))
    logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
    continue;
  end
  
  % Time to iterate through all the groups
  for git = 1:length(groupList)
    ncbar.setBarTitle(sprintf('Exporting bursts from group: %s', groupList{git}));
    % Again, for compatibility reasons
    if(strcmpi(groupList{git}, 'none'))
      groupList{git} = 'everything';
    end

    exportData = getExportData(experiment, groupList{git}, params.statisticsType);
    for j = 1:size(exportData, 1)
      fprintf(fID, fmt, exportData(j, :));
      fprintf(fID, fmtEnd, groupList{git}, experiment.name, checkedExperiments(itt));
    end
  end
end
fclose(fID);

        
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
function exportData = getExportData(experiment, subpop, type)
  experiment = checkGroups(experiment);
  exportData = [];
  if(~isfield(experiment, 'traceBursts'))
    logMsg(sprintf('Burst statistics not found in experiment %s', experiment.name), 'w');
    return;
  end

  try
    bursts = getExperimentGroupBursts(experiment, subpop);
  catch ME
    logMsg(sprintf('Something was wrong getting loading bursts from %s in experiment %s', subpop, experiment.name), 'e');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    return;
  end
  switch type
    case 'moments'
      exportData = nan(1, length(statisticsNames));
      for it = 1:length(statisticsNames)
        if(regexp(statisticsNames{it}, 'IBI$'))
          currentStat = bursts.IBI;
        elseif(regexp(statisticsNames{it}, 'Duration$'))
          currentStat = bursts.duration;
        elseif(regexp(statisticsNames{it}, 'Amplitude$'))
          currentStat = bursts.amplitude;
        else
          logMsg('Invalid statistic', 'w');
        end
        if(isempty(currentStat))
          continue;
        end
        if(regexp(statisticsNames{it}, '^avg'))
          exportData(it) = mean(currentStat);
        elseif(regexp(statisticsNames{it}, '^std'))
          exportData(it) = std(currentStat);
        elseif(regexp(statisticsNames{it}, '^ske'))
          exportData(it) = skewness(currentStat);
        elseif(regexp(statisticsNames{it}, '^kur'))
          exportData(it) = kurtosis(currentStat);
        elseif(regexp(statisticsNames{it}, '^min'))
          exportData(it) = min(currentStat);
        elseif(regexp(statisticsNames{it}, '^max'))
          exportData(it) = max(currentStat);
        else
          logMsg('Invalid statistic', 'w');
        end
      end
    case 'full'
      %exportData = nan(1, length(fullNames));
      %{'duration', 'amplitude', 'prev IBI', 'next IBI'};
      exportData = [bursts.duration(:), bursts.amplitude(:), [NaN; bursts.IBI(:)], [bursts.IBI(:); NaN]];
  end
end

end