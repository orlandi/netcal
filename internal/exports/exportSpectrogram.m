function projexp = exportSpectrogram(projexp, varargin)
% EXPORTSPECTROGRAM exports the spectrogram data
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
%    experiment = exportSpectrogram(experiment)
%    project = exportSpectrogram(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: export spectrogram
% parentGroups: fluorescence: basic: exports
% optionsClass: spectrogramOptions
% requiredFields: rawTraces, traceGroupsNames

[params, var] = processFunctionStartup(spectrogramOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Exporting spectrogram', true);
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
    outputFile = [dataFolder, experiment.name, '_spectrogramData.xlsx'];
    %save(outputFile, 'exportData', '-mat');
    exportDataCallback([], [], [], [], ...
                   exportData, ...
                   {'f', 'p'}, ...
                   experiment.name, [], ...
                   outputFile);

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
    
    outputFile = [dataFolder, project.name, '_spectrogramData.xlsx'];
    for i = 1:length(checkedExperiments)
      experimentName = project.experiments{checkedExperiments(i)};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      
      exportData = getExportData(experiment);
      exportDataCallback([], [], [], [], ...
                   exportData, ...
                   {'f (Hz)','p (dB)'}, ...
                   experimentName, [], ...
                   outputFile);
      %fullExportData = [fullExportData, exportData];
    end
    
    %save(outputFile, 'fullExportData', '-mat');
    
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

  function exportData = getExportData(experiment)
    experiment = checkGroups(experiment);
    experiment = loadTraces(experiment, 'raw');
    if(~isfield(experiment, 'rawTraces'))
      logMsg(sprintf('There are no raw traces in %s', experiment.name), 'w');
      exportData = [];
      return;
    end
    % Consistency checks
    subset = getExperimentGroupMembers(experiment, params.subpopulation);
    if(isempty(subset))
      logMsg(sprintf('No elements found for group in experiment %s', params.subpopulation, experiment.name), 'w');
      exportData = [];
      return;
    end
     avgTrace = mean(experiment.rawTraces(:, subset), 2);
    [pxx,f] = periodogram(avgTrace,[],length(avgTrace),experiment.fps);
    exportData = [f, 10*log10(pxx)];
  end
end
