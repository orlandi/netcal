function projexp = exportDataPopulations(projexp, varargin)
% EXPORTDATAPOPULATION exports the populations data for a project or an experiment
% In project mode it will run for all the checked experiments
%
% USAGE:
%    experiment = exportDataPopulations(project, varargin)
%    experiment = exportDataPopulations(experiment, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: exportPopulationsOptions
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportDataPopulations(experiment)
%    project = exportDataPopulations(project)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% PIPELINE
% name: export groups
% parentGroups: populations: exports
% optionsClass: exportPopulationsOptions
% requiredFields: ROI, traceGroups, folder, name

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(exportPopulationsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting subpopulations', true);
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
    [exportData, names] = getExportData(experiment, params);

    if(~exist(experiment.folder, 'dir'))
      mkdir(experiment.folder);
    end
    dataFolder = [experiment.folder 'data' filesep];
    if(~exist(dataFolder, 'dir'))
      mkdir(dataFolder);
    end
    outputFile = [dataFolder, experiment.name, '_populations', params.exportFileTag, '.', params.exportType];
    if(params.deleteOldFile && exist(outputFile, 'file'))
      delete(outputFile);
    end
    exportDataCallback([], [], [], [], ...
                       exportData, ...
                       names, ...
                       params.sheetName, [], ...
                       outputFile);
  case 'project'
    if(~strcmpi(params.exportType, 'xlsx'))
      logMsg('Full project populations can only be exported to xlsx files');
      return;
    end
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
    outputFile = [dataFolder, project.name, '_populations', params.exportFileTag, '.', params.exportType];
    if(params.deleteOldFile && exist(outputFile, 'file'))
      delete(outputFile);
    end
    for i = 1:length(checkedExperiments)
      experimentName = project.experiments{checkedExperiments(i)};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      
      [exportData, names] = getExportData(experiment, params);
      
      exportDataCallback([], [], [], [], ...
                       exportData, ...
                       names, ...
                       [params.sheetName '_' experiment.name], [], ...
                       outputFile);
      
    end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------


function [exportData, names] = getExportData(experiment, params)
  names = getExperimentGroupsNames(experiment);
  switch params.exportPopulationType
    case 'full'
      exportData = nan(length(experiment.ROI), length(names));
    case 'count'
      exportData = nan(1, length(names));
  end

  ROIid = getROIid(experiment.ROI);

  for it = 1:length(names)
    try
      members = getExperimentGroupMembers(experiment, names{it});
      switch params.exportPopulationType
        case 'full'
          exportData(1:length(members), it) = ROIid(members(:));
        case 'count'
          exportData(1, it) = length(members);
      end
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
      logMsg(sprintf('Could not load population %s. Skipping it', names{it}), 'e');
      continue;
    end
  end
end

end