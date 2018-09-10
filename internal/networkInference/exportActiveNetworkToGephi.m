function experiment = exportActiveNetworkToGephi(experiment, varargin)
% EXPORTACTIVENETWORKTOGEPHI Exports the active network to gephi
% It will genearte a .gexf format (version 1.2) that can directly be
% imported on GEPHI. You can add additional network measures as node
% attributes so you can use them in GEPHI
%
% USAGE:
%    experiment = exportActiveNetworkToGephi(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportActiveNetworkToGephiOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = exportActiveNetworkToGephi(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% EXPERIMENT PIPELINE
% name: export active network to Gephi
% parentGroups: network: exports
% optionsClass: exportActiveNetworkToGephiOptions
% requiredFields: RS, ROI, folder, name

[params, var] = processFunctionStartup(exportActiveNetworkToGephiOptions, varargin{:});
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
  
  % Do something
  network = struct;
  network.X = cellfun(@(x)x.center(1), experiment.ROI(members));
  network.Y = cellfun(@(x)x.center(2), experiment.ROI(members));
  network.RS = experiment.RS.(groupName){groupIdx};
  IDs = cellfun(@(x)x.ID, experiment.ROI(members));
  fileName = [exportFolder 'activeNetwork_' params.exportTag experiment.name strrep(groupList{git},':','_') '.gexf'];
  scoreList = {'ROI ID', IDs};
  % now the other scores
  
  defClass = exportActiveNetworkToGephiOptions;
  tmpClass = defClass.setExperimentDefaults(experiment);
  statList = tmpClass.additionalScore(1:end-2); % Removing last one since it's going to be 'all' andd ask'
  if(strcmpi(params.additionalScore, 'ask'))
    [selection, ok] = listdlg('PromptString', 'Select statistics to plot', 'ListString', statList, 'SelectionMode', 'multiple');
    if(~ok)
      return;
    end
  elseif(strcmpi(params.additionalScore, 'all'))
    selection = 1:length(statList);
  elseif(strcmpi(params.additionalScore, 'none'))
    selection = [];
  else
    selection = find(strcmp(statList, params.additionalScore));
  end
  
  for it = 1:length(selection)
    try
      curName = statList{selection(it)};
      curScore = computeNetworkStatistic(network.RS, curName, params.numberSurrogates);
      scoreList{end+1} = curName;
      scoreList{end+1} = curScore;
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'w');
    end
  end
  networkToGEXF(network, fileName, scoreList{:});
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end