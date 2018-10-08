function [experiment, trainingData] = spikeInferenceFoopsi(experiment, varargin)
% SPIKEINFERENCEFOOPSI Does spike detection using the foopsi algorithm
%
% USAGE:
%   experiment = spikeInferenceFoopsi(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class peelingOptions
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
%   experiment = spikeInferenceFoopsi(experiment, peelingOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also foopsiOptions

% EXPERIMENT PIPELINE
% name: foopsi inference
% parentGroups: spikes: inference
% optionsClass: foopsiOptions
% requiredFields: traces, rawTraces, t, fps
% producedFields: spikes

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(foopsiOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.subset = [];
params.spikeRasterTrain = false;
params.training = false;
params.storeProbability = false;
% Parse them
params = parse_pv_pairs(params, var);
if(params.training)
  params.pbar = 0;
end
params = barStartup(params, 'Running foopsi');
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

% Configure the foopsi
parameters = struct;
parameters.dt= 1/experiment.fps;
parameters.fast_iter_max = 15; %15;
parameters.fast_poiss = 0; %1=poisson/0=gaussian
parameters.fast_thr = 0;
parameters.plot = 0;
parameters.est_a = 1;
parameters.est_b = 1;
parameters.est_gam = 1;
parameters.est_lam = 1;
parameters.est_sig = 1;
parameters.probability = params.probabilityThreshold;
% Some test
%  parameters.est_a = 0;
%  parameters.est_b = 0;
%  parameters.est_gam = 0;
%  parameters.est_lam = 0;
%  parameters.est_sig = 0;
%V.a = 10.4807;
% V.b = -3.5772;
% V.gam = 0.95;
% V.lam = 0.6185;
% V.sig = 0.0674;
% parameters

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

if(params.storeProbability)
  experiment.firingProbability = zeros(size(traces));
end
% Do the actual peeling
for it = 1:length(subset)
  selectedTrace = subset(it);
  currentTrace = traces(:, selectedTrace)';
  
  %[pks, foopsiParams] = fast_oopsi(currentTrace, parameters, V);
  [pks, foopsiParams] = fast_oopsi(currentTrace, parameters);
  %foopsiParams
  % Just in case
  pks(1:5) = 0;
  if(params.storeProbability)
    experiment.firingProbability(:, selectedTrace) = pks';
  end
  switch params.probabilityThresholdType
    case 'absolute'
      firings = find(pks > parameters.probability);
    case 'relative'
      valid = pks > 1e-9; % Somewhat of a hack
      %valid = pks > 1e-3; % Somewhat of a hack
      %[nanmean(pks(valid)) nanstd(pks(valid)) nanmedian(pks(valid))]
      firings = find(pks > nanmean(pks(valid))+parameters.probability*nanstd(pks(valid)));
    case 'time varying'
      %blockSize = [round(params.probabilityThresholdBlockSize*experiment.fps), 1];
%       StDevFilterFunction = @(theBlockStructure) nanstd(double(theBlockStructure.data(:)));
%       blockStd = blockproc(pks(:), blockSize, StDevFilterFunction);
%       meanFilterFunction = @(theBlockStructure) nanmean(double(theBlockStructure.data(:)));
%       blockMean = blockproc(pks(:), blockSize, meanFilterFunction);
%       closestFrame = ceil((1:length(pks))/blockSize(1));
      %firings = find(pks > blockMean(closestFrame)+parameters.probability*blockStd(closestFrame));
      %threshold = blockMean(closestFrame)+parameters.probability*blockStd(closestFrame);
      pks(isnan(pks)) = 0; % Just in case
      blockSize = round(params.probabilityThresholdBlockSize*experiment.fps/2);
      blockSize = round((blockSize(1)-1)/2)*2+1;
      blockMean = filter(ones(blockSize(1), 1)/(blockSize(1)*2), 1, pks(:));
      blockStd = stdfilt([nan(floor(blockSize(1)/2), 1); pks(:)], ones(blockSize, 1));
      blockStd = blockStd((floor(blockSize(1)/2)+1):end);
      firings = find(pks > blockMean+parameters.probability*blockStd);
      threshold = blockMean+parameters.probability*blockStd;
  end
  if(params.spikeRasterTrain)
    subsetSpikes{it} = firings;
  else
    subsetSpikes{it} = experiment.t(firings);
  end
  if(params.training)
    trainingData = foopsiParams;
    trainingData.spikes = firings;
    trainingData.pks = pks;
  end
  % Now the generative model
  if(params.storeModelTrace || params.training)
    newC = zeros(size(currentTrace));
    newC(1) = 0;
    for it2 = 2:length(currentTrace)
      newC(it2) = newC(it2-1)*foopsiParams.gam;
      if(any(firings == it2))
        newC(it2) = newC(it2)+1;
      end
    end
    %F = foopsiParams.a*(newC+foopsiParams.b)+foopsiParams.sig*randn(size(newC)) + median(experiment.traces(:, selectedTrace));
    %F = foopsiParams.a*(newC+foopsiParams.b)+foopsiParams.sig*randn(size(newC)) + mean(experiment.traces(:, selectedTrace));
    %F = foopsiParams.a*newC+foopsiParams.b/foopsiParams.a+foopsiParams.sig*randn(size(newC));
%     foopsiParams
    F = foopsiParams.a/foopsiParams.b*newC+foopsiParams.b/foopsiParams.a+foopsiParams.sig*randn(size(newC));
    if(params.storeModelTrace)
      modelTraces(:, it) = F;
    end
    if(params.training)
      trainingData.model = F;
    end
  end
  if(params.pbar > 0 && ~params.training)
    ncbar.update(it/length(subset));
  end
end

if(params.training && params.showFiringProbability)
  figure;
  plot(experiment.t, trainingData.pks);
  xlabel('time (s)');
  ylabel('Firing probability');
  title('Firing probability plot');
  xl = xlim;
  yl = ylim;
  hold on;
  switch params.probabilityThresholdType
    case 'absolute'
      plot(xl, [1,1]*parameters.probability,'-');
    case 'relative'
      valid = trainingData.pks > 1e-9; % Somewhat of a hack
      plot(xl, [1,1]*(nanmean(trainingData.pks(valid))+parameters.probability*nanstd(trainingData.pks(valid))),'-');
    case 'time varying'
      plot(experiment.t, threshold, '-');
  end
  
  plot(experiment.t(trainingData.spikes), ones(size(trainingData.spikes))*yl(2)*1.1, 'o');
  legend('firing probability', 'spike detection threshold', 'spikes');
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

if(params.storeModelTrace)
  experiment.modelTraces(:, subset) = modelTraces;
  experiment.saveBigFields = true; % So the model traces are saved
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
