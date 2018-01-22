function experiment = exportROIcenters(experiment, varargin)
% EXPORTROICENTERS exports a list of ROI containing their centers
%
% USAGE:
%    experiment = exportROIcenters(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportROIcentersOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = exportROIcenters(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: export ROI centers
% parentGroups: groups: exports
% optionsClass: exportROIcentersOptions
% requiredFields: ROI, folder, name

[params, var] = processFunctionStartup(exportROIcentersOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting ROI centers', true);
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
  ncbar.setBarTitle(sprintf('Exporting ROI centers from group: %s', groupList{git}));
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
  
  tag = strrep(groupList{git}, ':', '_');
  %ROIid = getROIid(experiment.ROI);
  %labels = {'ROI ID', 'X', 'Y'};
  ROIlist = [cellfun(@(x)x.ID, experiment.ROI(members)),  cellfun(@(x)x.center(2), experiment.ROI(members)), cellfun(@(x)x.center(1), experiment.ROI(members))];
  
  switch params.fileType
    case 'csv'
      outputFile = [dataFolder, experiment.name, '_ROI_centers_' tag '.csv'];
      fID = fopen(outputFile, 'W');
      % Create and write the header
      fprintf(fID, 'ROI ID, X, Y\n');

      % Create the format for the statistics
      fmt = ['%d, ' params.numericFormat, ', ' params.numericFormat, '\n'];
    case 'txt'
      outputFile = [dataFolder, experiment.name, '_ROI_centers_' tag '.txt'];
      fID = fopen(outputFile, 'W');
      % No header
      % Create the format for the statistics
      fmt = ['%d ' params.numericFormat, ' ' params.numericFormat, '\n'];
  end
  
  exportData = sprintf(fmt, ROIlist');
  exportData = exportData(1:end-1); % remove last \n
  fprintf(fID, '%s', exportData); 
  fclose(fID);
end


%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end
