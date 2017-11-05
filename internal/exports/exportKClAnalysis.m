function experiment = exportKClAnalysis(experiment, varargin)
% EXPORTKCLANALYSIS exports data from the KCL analysis
%
% USAGE:
%    experiment = exportKClAnalysis(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportBaseGroupOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = exportFluorescenceFeatures(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: export KCl analysis results
% parentGroups: protocols: intra-experiment: KCl analysis: exports
% optionsClass: exportBaseGroupOptions
% requiredFields: KClProtocolData, ROI, folder, name

[params, var] = processFunctionStartup(exportBaseGroupOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting KCl analysis results', true);
%--------------------------------------------------------------------------


% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end


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
outputFileName = [dataFolder, experiment.name, '_KClAnalysisData' params.exportFileTag];

% Get ALL subgroups in case of parents
if(strcmpi(mainGroup, 'all'))
  groupList = getExperimentGroupsNames(experiment);
else
  groupList = getExperimentGroupsNames(experiment, mainGroup);
end

% Empty check
if(isempty(groupList))
  logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
  barCleanup(params);
  return;
end

[members, ~, ~] = getExperimentGroupMembers(experiment, groupList{1});

labels = {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime', 'decay', 'decayTime', 'recoveryTime', 'endValue', 'lastResponseValue'};
if(~isempty(experiment.KClProtocolData{members(1)}.fitRiseCoeffNames))
  for it = 1:length(experiment.KClProtocolData{members(1)}.fitRiseCoeffNames)
    labels{end+1} = sprintf('Rise coeff: %s', experiment.KClProtocolData{members(1)}.fitRiseCoeffNames{it});
  end
  labels{end+1} = sprintf('Rise rsquare');
end
if(~isempty(experiment.KClProtocolData{members(1)}.fitDecayCoeffNames))
  for it = 1:length(experiment.KClProtocolData{members(1)}.fitDecayCoeffNames)
    labels{end+1} = sprintf('Decay coeff: %s', experiment.KClProtocolData{members(1)}.fitDecayCoeffNames{it});
  end
  labels{end+1} = sprintf('Decay rsquare');
end
labels{end+1} = 'ROI';

%labels = [labels, {'group', 'experiment', 'experiment index'}];
labels = [labels, {'group', 'experiment'}];

%%% Preparing the CSV export
outputFile = [outputFileName '.csv'];
fID = fopen(outputFile, 'W');
% Create and write the header
fmt = repmat('%s, ',1, length(labels));
fmt = [fmt(1:end-2) '\n'];
fprintf(fID, fmt, labels{:});

%fmt = [repmat([params.numericFormat, ', '], 1, length(labels)-2) '%s, %d\n'];
fmt = [repmat([params.numericFormat, ', '], 1, length(labels)-2) '%d'];
fmtEnd = '%s, %s\n';
%fmtEnd = '%s, %s, %d\n';
  
% Main loop for the export data

% Time to iterate through all the groups
for git = 1:length(groupList)
  ncbar.setBarTitle(sprintf('Exporting KCl analysis results from group: %s', groupList{git}));

  [exportData, ~] = getKClFeatures(experiment, groupList{git}, 'ROI ID');
  for j = 1:size(exportData, 1)
    fprintf(fID, fmt, exportData(j, :));
    fprintf(fID, fmtEnd, groupList{git}, experiment.name);
    %fprintf(fID, fmtEnd, groupList{git}, experiment.name, checkedExperiments(itt));
  end
end

fclose(fID);
        
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end