function [experiment, trainingData] = spikeInferencePeeling(experiment, varargin)
% SPIKEINFERENCEPEELING # Spike detection using a modified version (for speed) of the peeling algorithm
%
% USAGE:
%   experiment = spikeInferencePeeling(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class peelingOptions
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
%   subset - only get spikes for a particular subset of traces (idx list)
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = spikeInferencePeeling(experiment, peelingOptions)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also peelingOptions

% EXPERIMENT PIPELINE
% name: peeling (fast) inference
% parentGroups: spikes: inference
% optionsClass: peelingOptions
% requiredFields: traces, rawTraces, t, fps
% producedFields: spikes


%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(peelingOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.subset = [];
params.training = false;
% Parse them
params = parse_pv_pairs(params, var);
if(~params.training)
  params = barStartup(params, 'Performing peeling');
end
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

% Configure the peeling
[ca_p, peel_p, exp_p] = configurePeeling(experiment, traces, ...
                                           'amp1', params.amplitude, ...,
                                           'amp2', params.secondAmplitude, ...
                                           'tau1', params.tau, ...
                                           'tau2', params.secondTau, ...
                                           'verbose', false);

peelingSpikeTrains = zeros(size(traces(:, length(subset))));
peelingModelTraces = zeros(size(traces(:, length(subset))));
peelingSpikes = cell(length(subset), 1);

if(isempty(params.pbar) && params.verbose && ~params.training)
  pbar('Peeling');
  params.pbar = 1;
elseif(params.verbose && ~isempty(params.pbar) && ~params.training)
  ncbar.setCurrentBarName('Peeling');
end

% Do the actual peeling
for it = 1:length(subset)
  selectedTrace = subset(it);
  [~, ~, ~, peelingData] = Peeling(traces(:, selectedTrace)', ...
                           experiment.fps, ca_p, exp_p, peel_p);
  peelingSpikeTrains(:, it) = peelingData.spiketrain';
  peelingModelTraces(:, it) = peelingData.model';
  peelingSpikes{it} = experiment.t(1)+peelingData.spikes-peelingData.tim(1);
  
  if(~isempty(params.pbar) && params.verbose && ~params.training)
    ncbar.update(it/length(subset));
  end
end

if(params.training || (params.verbose && params.pbar == 1))
  logMsgHeader('Done!', 'finish');
end

if(params.training)
  trainingData = peelingData;
  return;
else
  trainingData = [];
end

for it = 1:length(subset)
  experiment.spikes{subset(it)} = peelingSpikes{it};
end

if(~params.training)
  %--------------------------------------------------------------------------
  barCleanup(params);
  %--------------------------------------------------------------------------
end

end