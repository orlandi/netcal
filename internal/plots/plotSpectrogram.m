function projexp = plotSpectrogram(projexp, varargin)
% PLOTSPECTROGRAM plots the spectrogram data
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
%    experiment = plotSpectrogram(experiment)
%    project = plotSpectrogram(project)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% PIPELINE
% name: plot spectrogram
% parentGroups: fluorescence: basic: plots
% optionsClass: spectrogramOptions
% requiredFields: rawTraces, traceGroupsNames

[params, var] = processFunctionStartup(spectrogramOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Plotting spectrogram', true);
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

h = figure;
hold on;
switch mode
  case 'experiment'
    data = getExportData(experiment);
    f = data(:, 1);
    pxx = data(:, 2);
    plot(f, pxx);
  case 'project'
    checkedExperiments = find(project.checkedExperiments);
    if(isempty(checkedExperiments))
      logMsg('No checked experiments found', 'e');
      return;
    end
    fullPxx = [];
    for i = 1:length(checkedExperiments)
      experimentName = project.experiments{checkedExperiments(i)};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      
      data = getExportData(experiment);
      if(~params.showConfidenceInterval)
        f = data(:, 1);
        pxx = data(:, 2);
        plot(f, pxx);
      else
        try
          fullPxx = [fullPxx, data(:, 2)];
        catch ME
          logMsg(sprintf('All traces should be the same length to compute CIs. Failed in experiment %s', experimentName), 'e');
          logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
          return;
        end
        f = data(:, 1);
      end
    end
    if(params.showConfidenceInterval)
      size(fullPxx)
      plot(f, mean(fullPxx, 2));
      hr = plot(f, mean(fullPxx, 2)+1.96*std(fullPxx, [], 2));
      hrr = plot(f, mean(fullPxx, 2)-1.96*std(fullPxx, [], 2));
      hrr.Color = hr.Color;
    end
end
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
box on;
set(h,'Color','w');
ui = uimenu(h, 'Label', 'Export');
uimenu(ui, 'Label', 'Image',  'Callback', {@exportFigCallback, {'*.png'; '*.tiff'; '*.pdf'; '*.eps'}, [experiment.folder 'spectrogram']});
  
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
    [pxx_,f_] = periodogram(avgTrace,[],length(avgTrace),experiment.fps);
    exportData = [f_, 10*log10(pxx_)];
  end
end
