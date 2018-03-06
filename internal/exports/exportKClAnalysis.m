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
% parentGroups: protocols: KCl analysis: exports
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

% Find maximum number of segments
maxSegments = 0;
for git = 1:length(groupList)
  [~, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupList{git});
  maxSegments = max([maxSegments; experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegments]);
end

%labels = {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime', 'decay', 'decayTime', 'recoveryTime', 'endValue', 'lastResponseValue'};

originalLabels = {'baseLine', 'reactionTime', 'maxResponse', 'maxResponseTime', ...
          'decay', 'decayTime', 'responseDuration', 'recoveryTime', 'recovered', ...
          'protocolEndValue', 'lastResponseValue', ...
          'responseFitSegments', 'responseFitSegmentsMaxFluorescenceIncrease', 'responseFitSegmentsMaxSlope'};
labels = originalLabels;
for it = 1:maxSegments
  labels = [labels, {sprintf('seg: %d F inc', it), sprintf('seg: %d dur', it), sprintf('seg: %d slope', it)}];
end

labels = [labels, {'ROI', 'group', 'experiment'}];

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
ROIid = getROIid(experiment.ROI);
% Time to iterate through all the groups
for git = 1:length(groupList)
  [members, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupList{git});
  ncbar.setBarTitle(sprintf('Exporting KCl analysis results from group: %s', groupList{git}));
  exportData = nan(length(members), length(labels)-2);
  % Copy info from original labels
  for it = 1:length(originalLabels)
    exportData(:, it) = experiment.KClProtocolData.(groupName){groupIdx}.(originalLabels{it});
  end
  exportData(:, end) = ROIid(members);
  
  %[exportData, ~] = getKClFeatures(experiment, groupList{git}, 'ROI ID');
  for j = 1:size(exportData, 1)
    % Now let's add segment info
    curPos = length(originalLabels);
    for it = 1:experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegments(j)
      curPos = curPos+1;
      exportData(j, curPos) = experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegmentsFluorescenceIncrease{j}(it);
      curPos = curPos+1;
      exportData(j, curPos) = experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegmentsDuration{j}(it);
      curPos = curPos+1;
      exportData(j, curPos) = experiment.KClProtocolData.(groupName){groupIdx}.responseFitSegmentsSlope{j}(it);
    end
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