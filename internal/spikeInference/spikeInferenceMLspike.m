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
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also MLspikeOptions

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

if(isempty(params.a)  || params.a == 0)
  estimateA = true;
else
  estimateA = false;
end
if(isempty(params.tau)  || params.tau == 0)
  estimateTau = true;
else
  estimateTau = false;
end


% Do the actual MLspike
par = spk_est('par');
par.dt = 1/experiment.fps;
par.drift.parameter = 1;
par.display = 'none';
%par.algo.dogpu = true;
par.dographsummary = params.showSummary;
if(~isempty(params.a))
  par.a = params.a;
end
if(~isempty(params.tau))
  par.tau = params.tau;
end

if(params.training && params.parallel)
  params.parallel = false;
  logMsg('Parallel mode cannot be used during training', 'w');
end
apar = [];
apar.dt = 1/experiment.fps;
MLspikeParams = cell(length(subset), 1);
switch params.automaticEstimationMode
  case 'trainingROI'
    if(estimateA || estimateTau)
      params.pbarCreated = true;
      params.pbar = 1;
      ncbar.automatic('Autocalibrating parameters');
      
      if(isempty(params.trainingROI))
        selectedROI = subset(randperm(length(subset), 1));
      else
        ROIid = getROIid(experiment.ROI);
        selectedROI = find(ROIid == params.trainingROI);
      end
      logMsg(sprintf('Autocalibrating MLspike paramters with ROI: %d', experiment.ROI{selectedROI}.ID));
      currentTrace = traces(:, selectedROI)';
      [tau, amp, sigma, ~] = spk_autocalibration(currentTrace, apar);
      logMsg(sprintf('MLspike autocalibration parameters: tau: %.3f ampa: %.3f sigma: %.3f', tau, amp, sigma));
      if(estimateA)
        par.a = amp;
      end
      if(estimateTau)
        par.tau = tau;
      end
      for it = 1:length(subset)
        MLspikeParams{it}.tau = tau;
        MLspikeParams{it}.a = amp;
        MLspikeParams{it}.sigma = sigma;
      end
      
    end
    case 'all'
      apar.display = 'none';
end
if(params.training)
  params.pbarCreated = true;
  params.pbar = 1;
  ncbar.automatic('Running MLspike');
end

if(~params.parallel)
  Ntraces = length(subset);
  for it = 1:length(subset)
    selectedTrace = subset(it);
    currentTrace = traces(:, selectedTrace)';
    switch params.automaticEstimationMode
      case 'all'
        [tau, amp, sigma, ~] = spk_autocalibration(currentTrace, apar);
        if(estimateA)
          par.a = amp;
        end
        if(estimateTau)
          par.tau = tau;
        end
        if(isempty(par.a) || isempty(par.tau))
          logMsg(sprintf('Autocalibration failed on trace: %d. Using default values', experiment.ROI{selectedTrace}.ID), 'w');
          par.a = 0.1;
          par.tau = 1;
        end
          
        MLspikeParams{it}.tau = tau;
        MLspikeParams{it}.a = amp;
        MLspikeParams{it}.sigma= sigma;
    end
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
       ncbar.update(it/Ntraces);
     end
  end
else
  switch params.automaticEstimationMode
      case 'all'
        logMsg('Automatic calibration in parallel mode not supported. (Me being lazy)', 'e');
  end
  if(params.pbar > 0)
    ncbar.setBarName('Initializing cluster');
    ncbar.setAutomaticBar();
  end
  cl = parcluster('local');
  Ntraces = length(subset);
  for it = 1:Ntraces
    selectedTrace = subset(it);
    currentTrace = traces(:, selectedTrace)';
    futures(it) = parfeval(@spk_est, 4, currentTrace, par);
  end

  numCompleted = 0;
  ncbar.unsetAutomaticBar();
  while numCompleted < Ntraces
    if(params.pbar > 0)
      ncbar.setBarName(sprintf('Running parallel MLspike (%d/%d)', numCompleted, Ntraces));
      ncbar.update(numCompleted/Ntraces);
    end
    [completedIdx, spk, fit, ~, ~] = fetchNext(futures);
    subsetSpikes{completedIdx} = spk;
    if(params.storeModelTrace)
      modelTraces(:, completedIdx) = fit;
    end
    numCompleted = numCompleted + 1;
    if(params.pbar > 0)
      ncbar.update(numCompleted/Ntraces);
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

experiment.MLspikeParams = MLspikeParams;
%  if(~isfield(experiment, 'MLspikeParams'))
%     experiment.MLspikeParams = MLspikeParams;
%     %experiment.MLspikeParams(members) = MLspikeParams;
%   else
%     try
%       experiment.MLspikeParams(members) = MLspikeParams;
%     catch ME
%       experiment.MLspikeParams = cell(size(traces, 2), 1);
%       experiment.MLspikeParams(members) = MLspikeParams;
%       logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
%     end
%  end
  
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
