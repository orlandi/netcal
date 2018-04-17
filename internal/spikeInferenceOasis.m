function [experiment, trainingData] = spikeInferenceOasis(experiment, varargin)
% SPIKEINFERENCEOASIS Does spike detection using the oasis algorithm
%
% USAGE:
%   experiment = spikeInferenceOasis(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class oasisOptions
%
% INPUT optional arguments ('key' followed by its value):
%   subset - only get spikes for a particular subset of traces (idx list)
%
%   training - (true/false) if we are traning on a single trace
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
%   trainingData - structure containing the training data
% EXAMPLE:
%   experiment = spikeInferenceOasis(experiment, oasisOptions)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also foopsiOptions

% EXPERIMENT PIPELINE
% name: oasis inference
% parentGroups: spikes: inference
% optionsClass: oasisOptions
% requiredFields: traces, rawTraces, t, fps
% producedFields: spikes

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(oasisOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.subset = [];
params.spikeRasterTrain = false;
params.training = false;
% Parse them
params = parse_pv_pairs(params, var);
if(params.training)
  params.pbar = 0;
end
params = barStartup(params, 'Running oasis');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

if(params.training && params.parallel)
  params.parallel = false;
  logMsg('Parallel mode cannot be used during training', 'w');
end

members = getAllMembers(experiment, mainGroup);

if(params.pbar > 0)
  ncbar.setCurrentBarName('Loading traces');
  ncbar.setAutomaticBar();
end
switch params.tracesType
  case 'smoothed'
    experiment = loadTraces(experiment, 'normal');
    traces = experiment.traces;
  case 'raw'
    experiment = loadTraces(experiment, 'raw');
    traces = experiment.rawTraces;
  case 'denoised'
    experiment = loadTraces(experiment, 'rawTracesDenoised');
    traces = experiment.rawTracesDenoised;
end
if(params.pbar > 0)
  ncbar.setCurrentBarName('Running oasis');
  ncbar.unsetAutomaticBar();
end

if(isempty(params.subset))
  subset = members;
else
  subset = params.subset;
end

if(~isfield(experiment, 'spikes') || length(experiment.spikes) ~= size(traces, 2) && ~params.training)
  experiment.spikes = cell(size(traces,2), 1);
  for it = 1:length(experiment.spikes)
    experiment.spikes{it} = nan(1, 1);
  end
end    

if(params.storeModelTrace)
  if(~isfield(experiment, 'modelTraces'))
    experiment.modelTraces = zeros(size(traces));
  elseif(size(experiment.modelTraces,1) ~= size(traces,1) || size(experiment.modelTraces,2) ~= size(traces,2))
    logMsg('Mismatch between real and model traces sizes detected. Resetting model traces', 'w');
    experiment.modelTraces = zeros(size(traces));
  end
  modelTraces = zeros(size(traces(:, length(subset))));
end
subsetSpikes = cell(length(subset), 1);

if(params.parallel)
  if(params.pbar > 0)
    ncbar.setBarName('Initializing cluster');
    ncbar.setAutomaticBar();
  end
  cl = parcluster('local');
  
  %futures(it) = parfeval(@spk_est, 4, currentTrace, par);
  
end

% Do the actual oasis
snList = zeros(length(subset), 1);
nsList = zeros(length(subset), 1);
for it = 1:length(subset)
  selectedTrace = subset(it);
  currentTrace = traces(:, selectedTrace)';
  
  %[pks, foopsiParams] = fast_oopsi(currentTrace, parameters, V);
  %[pks, foopsiParams] = fast_oopsi(currentTrace, parameters);
  varOpts = {};
  if(params.smin > 0)
    varOpts{end+1} = 'smin';
    varOpts{end+1} = params.smin;
  else
    varOpts{end+1} = 'optimize_smin';
  end
  if(params.sn > 0)
    varOpts{end+1} = 'sn';
    varOpts{end+1} = params.sn;
  end
  if(~isempty(params.pars))
    varOpts{end+1} = 'pars';
    varOpts{end+1} = eval(params.pars);
  end
  if(~isempty(params.window))
    varOpts{end+1} = 'window';
    varOpts{end+1} = params.window;
  end
  if(~isempty(params.shift))
    varOpts{end+1} = 'shift';
    varOpts{end+1} = params.shift;
  end
%  varOpts
  % Conver to double just to be sure
  if(~params.parallel)
    [c_oasis, s_oasis, options] = deconvolveCa(double(currentTrace), params.model, ...
                params.method, 'lambda', params.lambda, 'optimize_pars', 'optimize_b', varOpts{:});
    if(params.training)
      options
    end
    snList(it) = options.sn;
    nsList(it) = length(find(s_oasis));
    firings = find(s_oasis);

    if(params.spikeRasterTrain)
      subsetSpikes{it} = firings;
    else
      subsetSpikes{it} = experiment.t(firings);
    end
    if(params.training)
      trainingData.spikes = firings;
    end

    % Now the generative model
    if(params.storeModelTrace || params.training)
      if(params.storeModelTrace)
        modelTraces(:, it) = c_oasis;
      end
      if(params.training)
        trainingData.model = c_oasis;
      end
    end
    if(params.pbar > 0 && ~params.training)
      ncbar.update(it/length(subset));
    end
  else
    % Do it in parallel
    futures(it) = parfeval(@deconvolveCa, 3, double(currentTrace), params.model, ...
                params.method, 'lambda', params.lambda, 'optimize_pars', 'optimize_b', varOpts{:});
  end
end
if(params.parallel)
  numCompleted = 0;
  if(params.pbar > 0)
    ncbar.unsetAutomaticBar();
  end
  while numCompleted < length(subset)
    if(params.pbar > 0)
      ncbar.setBarName(sprintf('Running parallel MLspike (%d/%d)', numCompleted, length(subset)));
      ncbar.update(numCompleted/length(subset));
    end
    [completedIdx, c_oasis, s_oasis, options] = fetchNext(futures);
    snList(completedIdx) = options.sn;
    nsList(completedIdx) = length(find(s_oasis));
    firings = find(s_oasis);

    if(params.spikeRasterTrain)
      subsetSpikes{completedIdx} = firings;
    else
      subsetSpikes{completedIdx} = experiment.t(firings);
    end
    if(params.training)
      trainingData.spikes = firings;
    end

    % Now the generative model
    if(params.storeModelTrace || params.training)
      if(params.storeModelTrace)
        modelTraces(:, completedIdx) = c_oasis;
      end
    end
    numCompleted = numCompleted + 1;
    if(params.pbar > 0)
      ncbar.update(numCompleted/length(subset));
    end
  end
  cancel(futures);
end
if(params.training)
  barCleanup(params);
  return;
else
  trainingData = [];
end

if(params.spikeRasterTrain)
  experiment.spikes = nan(size(traces));
  for it = 1:length(subset)
    experiment.spikes(subsetSpikes{it}, subset(it)) = 1;
  end
else
  for it = 1:length(subset)
    experiment.spikes{subset(it)} = subsetSpikes{it};
  end
end

% if(length(subset) > 1)
%   figure;
%   plot(nsList, snList,'.');
% end

if(params.storeModelTrace)
  experiment.modelTraces(:, subset) = modelTraces;
  experiment.saveBigFields = true; % So the model traces are saved
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
