function projexp = exportLearningData(projexp, varargin)
% EXPORTLEARNINGDATA exports the learning data for a project or an experiment
% In project mode it will run for all the checked experiments
%
% USAGE:
%    experiment = exportDataPopulations(project, varargin)
%    experiment = exportDataPopulations(experiment, varargin)
%
% INPUT arguments:
%    (project/experiment) - project or experiment structure
%
% OUTPUT arguments:
%    (project/experiment) - project or experiment structure
%
% EXAMPLE:
%    experiment = exportLearningData(experiment)
%    project = exportLearningData(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export learning data
% parentGroups: fluorescence: group classification: feature-based: exports
% requiredFields: learningGroup, traceGroupsNames

[params, var] = processFunctionStartup([], varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
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
    if(~exist(experiment.folder, 'dir'))
      mkdir(experiment.folder);
    end
    dataFolder = [experiment.folder 'data' filesep];
    if(~exist(dataFolder, 'dir'))
      mkdir(dataFolder);
    end
    exportData = getExportData(experiment);
    outputFile = [dataFolder, experiment.name, '_learningData.dat'];
    save(outputFile, 'exportData', '-mat');
    
  case 'project'
    
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
    
    fullExportData = [];
    for i = 1:length(checkedExperiments)
      experimentName = project.experiments{checkedExperiments(i)};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      
      exportData = getExportData(experiment);
      fullExportData = [fullExportData; exportData];
    end
    outputFile = [dataFolder, project.name, '_learningData.dat'];
    save(outputFile, 'fullExportData', '-mat');
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  function exportData = getExportData(experiment)
    experiment = checkGroups(experiment);
    if(~isfield(experiment, 'features') || all(isnan(experiment.learningGroup)))
      logMsg(sprintf('There are no samples in %s', experiment.name), 'w');
      exportdata = [];
      return;
    end
    % Consistency checks
    if(~isfield(experiment, 'features'))
      logMsg(sprintf('No features found in %s', experiment.name), 'w');
      exportData = [];
      return;
    end
    trainingGroups = length(experiment.traceGroupsNames.classifier);
    trainingTraces = cell(trainingGroups, 1);
    for it = 1:numel(trainingTraces)
      trainingTraces{it} = find(experiment.learningGroup == it)';
    end
    % Create the response vector
    response = [];
    trainingTracesVector = [];
    for it = 1:length(trainingTraces)
      response = [response, it*ones(1,length(trainingTraces{it}))];
      trainingTracesVector = [trainingTracesVector, trainingTraces{it}];
     end
    trainingTraces = trainingTracesVector;
    exportData = [experiment.features(trainingTraces, :), response'];
  end
end
