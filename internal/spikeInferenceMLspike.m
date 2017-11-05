function [experiment, trainingData] = spikeInferenceMLspike(experiment, varargin)
% SPIKEINFERENCEMLSPIKE Does spike detection using the MLspike algorithm
%
% USAGE:
%   experiment = spikeInferenceMLspike(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class MLspikeOptions
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
%   experiment = spikeInferenceMLspike(experiment, MLspikeOptions)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also foopsiOptions

% EXPERIMENT PIPELINE
% name: MLspike inference
% parentGroups: spikes: inference
% optionsClass: MLspikeOptions
% requiredFields: traces, rawTraces, t, fps
% producedFields: spikes

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(MLspikeOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.subset = [];
params.training = false;
% Parse them
params = parse_pv_pairs(params, var);
if(params.training)
  params.pbar = 0;
end
params = barStartup(params, 'Running MLspike');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

members = getAllMembers(experiment, mainGroup);

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


% Do the actual MLspike
par = spk_est('par');
par.dt = 1/experiment.fps;
par.display = 'none';
par.dographsummary = params.showSummary;
par.a = params.a;
par.tau = params.tau;

for it = 1:length(subset)
  selectedTrace = subset(it);
  currentTrace = traces(:, selectedTrace)';
  
  [spk, fit, ~, ~] = spk_est(currentTrace, par);


  subsetSpikes{it} = spk;
  
  if(params.training)
    trainingData.spikes = round(spk*experiment.fps);
  end
  
  % Now the generative model
  if(params.storeModelTrace || params.training)
    if(params.storeModelTrace)
      modelTraces(:, it) = fit;
    end
    if(params.training)
      trainingData.model = fit;
    end
  end
  if(params.pbar > 0 && ~params.training)
    ncbar.update(it/length(subset));
  end
end

if(params.training)
  barCleanup(params);
  return;
else
  trainingData = [];
end


for it = 1:length(subset)
  experiment.spikes{subset(it)} = subsetSpikes{it};
end

if(params.storeModelTrace)
  experiment.modelTraces(:, subset) = modelTraces;
  experiment.saveBigFields = true; % So the model traces are saved
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
