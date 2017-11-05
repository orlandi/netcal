function experiment = exportDataTraces(experiment, varargin)
% EXPORTDATATRACES exports the traces data
%
% USAGE:
%    experiment = exportDataTraces(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportTracesOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = exportDataTraces(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: export traces
% parentGroups: fluorescence: basic: exports
% optionsClass: exportTracesOptions
% requiredFields: rawT, t, rawTraces, traces, ROI, folder, name

[params, var] = processFunctionStartup(exportTracesOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting traces', true);
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
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
  return;
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
% Time to iterate through all the groups
for git = 1:length(groupList)
  ncbar.setBarTitle(sprintf('Exporting traces from group: %s', groupList{git}));
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
  else
    members = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members))
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  % We will get the members later
  switch params.tracesType
    case 'smoothed'
      experiment = loadTraces(experiment, 'normal');
      t = experiment.t;
      traces = experiment.traces;
      tag = ['_smoothed_', strrep(groupList{git},': ','_')];
    case 'raw'
      experiment = loadTraces(experiment, 'raw');
      t = experiment.rawT;
      traces = experiment.rawTraces;
      tag = ['_raw_', strrep(groupList{git},': ','_')];
    case 'denoised'
      experiment = loadTraces(experiment, 'rawTracesDenoised');
      t = experiment.rawTDenoised;
      traces = experiment.rawTraces;
      tag = ['_rawDenoised_', strrep(groupList{git},': ','_')];
  end

  ROIid = getROIid(experiment.ROI);
  labels = cell(1, length(members)+1);
  labels{1} = 'time (s)';
  for i = 2:length(labels)
    if(iscell(ROIid))
      labels{i} = ROIid(members(i-1));
    else
      labels{i} = num2str(ROIid(members(i-1)));
    end
  end

  switch params.fileType
    case 'csv'
      outputFile = [dataFolder, experiment.name, '_traces' tag '.csv'];
      fID = fopen(outputFile, 'W');
      % Create and write the header
      fullNames = labels;
      fmt = repmat('%s, ',1, length(fullNames));
      fmt = [fmt(1:end-2) '\n'];
      fprintf(fID, fmt, fullNames{:});

      % Create the format for the statistics
      fmt = repmat([params.numericFormat, ', '], 1, length(labels));
      fmt = [fmt(1:end-2) '\n'];
    case 'txt'
      outputFile = [dataFolder, experiment.name, '_traces' tag '.txt'];
      fID = fopen(outputFile, 'W');
      % No header
      % Create the format for the statistics
      fmt = repmat([params.numericFormat, ' '], 1, length(labels));
      fmt = [fmt(1:end-1) '\n'];
  end
  
  % Transpose since matlab outputs column ordering
  exportData = [experiment.t, traces(:, members)]';
  fprintf(fID, fmt, exportData);
  fclose(fID);
end


%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
