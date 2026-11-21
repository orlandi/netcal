function experiment = exportActiveNetwork(experiment, varargin)
% EXPORTACTIVENETWORKTOGEPHI Exports the active network to a mat file
%
% USAGE:
%    experiment = exportActiveNetwork(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportActiveNetworkOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = exportActiveNetwork(experiment)
%
% Copyright (C) 2016-2025, Javier G. Orlandi <javier.orlandi@ucalgary.ca>

% EXPERIMENT PIPELINE
% name: export active network
% parentGroups: network: exports
% optionsClass: exportActiveNetworkOptions
% requiredFields: RS, ROI, folder, name

[params, var] = processFunctionStartup(exportActiveNetworkOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting active network', true);
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end
% Check if its a project or an experiment
switch params.exportBaseFolder
  case 'experiment'
    baseFolder = experiment.folder;
  case 'project'
    baseFolder = [experiment.folder '..' filesep];
  otherwise
    baseFolder = experiment.folder;
end

% Consistency checks

% Create necessary folders
if(~exist(baseFolder, 'dir'))
  mkdir(baseFolder);
end
exportFolder = [baseFolder 'exports' filesep];
if(~exist(exportFolder, 'dir'))
  mkdir(exportFolder);
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
if(isfield(experiment, 'RS'))
    experiment = loadBigFields(experiment, {'RS'});
end
% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Exporting active network from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    members = 1:length(experiment.ROI);
    groupName = 'everything';
    groupIdx = 1;
  else
    [members, groupName, groupIdx] = getExperimentGroupMembers(experiment, groupList{git});
  end
  
  % Check for empty group
  if(isempty(members) && params.verbose)
    logMsg(sprintf('Found empty group: %s', groupList{git}), 'w');
    continue;
  end
  
  % Prepare the data to save
  X = cellfun(@(x)x.center(1), experiment.ROI(members));
  Y = cellfun(@(x)x.center(2), experiment.ROI(members));
  binarized = experiment.RS.(groupName){groupIdx};
  originalIDs = members;

  switch params.inferenceMeasure
    case 'GTE'
      raw = experiment.GTE.(groupName){groupIdx}(:, :, 1);
      normalized = experiment.GTE.(groupName){groupIdx}(:, :, 2);
    case 'GTE unconditioned'
      raw = experiment.GTEunconditioned.(groupName){groupIdx}(:, :, 1);
      normalized = experiment.GTEunconditioned.(groupName){groupIdx}(:, :, 2);
  end
  if(~isempty(params.exportTag))
    params.exportTag = [params.exportTag '_'];
  end
  fileName = [exportFolder experiment.name '_' 'network_' params.exportTag strrep(groupList{git},':','_') '.mat'];
  
  % Save the file
  save(fileName, 'X', 'Y', 'originalIDs', 'binarized', 'raw', 'normalized');
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end