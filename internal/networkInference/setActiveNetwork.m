function experiment = setActiveNetwork(experiment, varargin)
% SETACTIVENETWORK Sets some network inference measure as the active network (adjacency matrix)
%
% USAGE:
%   experiment = setActiveNetwork(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class setActiveNetworkOptions
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = setActiveNetwork(experiment, setActiveNetworkOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also setActiveNetworkOptions

% EXPERIMENT PIPELINE
% name: set Active Network
% parentGroups: network
% optionsClass: setActiveNetworkOptions
% requiredFields: fps, numFrames, width, height
% producedFields: RS
  
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(setActiveNetworkOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Setting active network');
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

% Time to iterate through all the groups
for git = 1:length(groupList)
  if(params.pbar > 0)
    ncbar.setBarTitle(sprintf('Setting active network from group: %s', groupList{git}));
  end
  if(strcmpi(groupList{git}, 'none'))
    groupList{git} = 'everything';
  end

  [field, idx] = getExperimentGroupCoordinates(experiment, groupList{git});

  switch params.inferenceMeasure
    case 'GTE'
      RS = (experiment.GTE.(field){idx}(:, :, 2) > params.confidenceLevelThreshold);
    case 'GTE unconditioned'
      RS = (experiment.GTEunconditioned.(field){idx}(:, :, 2) > params.confidenceLevelThreshold);  
  end
  experiment.RS.(field){idx} = double(RS);
end
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

