function [success, log] = executeExperimentFunctions(project, experimentIndex, functionHandleList, optionsList, varargin)
% EXECUTEEXPERIMENTFUNCTIONS executes a bunch of functions on a given experiment
%
% USAGE:
%    success = executeExperimentFunctions(project, experimentFile, functionList, optionsList, varargin)
%
% INPUT arguments:
%    project - project structure
%
%    experimentIndex - index of the experiment in the project list
%
%    functionHandleList - cell containing the function handles
%
%    optionsList - cell containing the options classes for each function handle
%
% INPUT optional arguments ('key' followed by its value):
%    verbose - verbose
%
% OUTPUT arguments:
%    success - if everything succeeded
%
% EXAMPLE:
%    experiment = smoothTraces(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

% Pass class options
params.pbar = [];
params.verbose = true;
params.parallel = false;
% Parse them
params = parse_pv_pairs(params, varargin);

log = [];
success = true;
experimentName = project.experiments{experimentIndex};
experimentFile = [project.folderFiles experimentName '.exp'];

infoMsg = sprintf('Processing %s', experimentName);

if(params.verbose)
  logMsgHeader(infoMsg, 'start');
end
pbarCreated = false;
if(isempty(params.pbar))
  pbar(infoMsg, '');
  params.pbar = ncbar.getNumberBars();
  pbarCreated = true;
elseif(params.pbar > 0)
  ncbar.setCurrentBar(params.pbar-1);
end

experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project, 'pbar', params.pbar);

if(isempty(experiment))
  log = [log, logMsg(['Something went wrong loading experiment ' experimentName], 'e')];
  success = false;
  return;
end

% For each funciton in the list, do the analysis
for f = 1:length(functionHandleList)
  oldExperiment = experiment;
  %nodeList{f}.Name = sprintf('<html><font color="red">%s</font></html>', regexprep(nodeList{f}.Name, '<[^>]*>', ''));
  analysisFunction = functionHandleList{f};
  
  infoMsg = sprintf('Processing %s (%d/%d)', functionHandleList{f}, f, length(functionHandleList));
  if(params.pbar > 0)
    ncbar.setCurrentBar(params.pbar-1);
    ncbar.update((f-1)/length(functionHandleList), 'force');
    infoMsg = sprintf('Processing %s (%d/%d)', functionHandleList{f}, f, length(functionHandleList));
    ncbar.setCurrentBarName(infoMsg);
    ncbar.setCurrentBar(params.pbar);
  end
  if(params.verbose)
    log = [log, logMsg(infoMsg)];
  end
  
  if(~isempty(optionsList{f}))
    optionsClassCurrent = optionsList{f};
    try
      experiment = feval(analysisFunction, experiment, optionsClassCurrent, 'pbar', params.pbar, 'verbose', params.verbose);
      experiment.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
    catch ME
      log = [log, logMsg(sprintf('Something went wrong while processing %s on experiment %s:', analysisFunction, experiment.name), 'e')];
      log = [log, logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e')];
      success = false;
      continue;
    end
  else
    try
      experiment = feval(analysisFunction, experiment, 'pbar', params.pbar, 'verbose', params.verbose);
    catch ME
      log = [log, logMsg(sprintf('Something went wrong while processing %s on experiment %s:', analysisFunction, experiment.name), 'e')];
      log = [log, logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e')];
      success = false;
      continue;
    end
  end
  %nodeList{f}.Name = sprintf('<html><font color="blue">%s</font></html>', regexprep(nodeList{f}.Name, '<[^>]*>', ''));
  if(params.pbar > 0)
    ncbar.setCurrentBar(params.pbar-1);
    ncbar.update(f/length(functionHandleList), 'force');
  end
  % Only save the experiment if it changed
  if(~isequaln(oldExperiment, experiment))
    saveExperiment(experiment, 'verbose', false, 'pbar', params.pbar);
  end
end

if(pbarCreated)
  ncbar.close();
end

