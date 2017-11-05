function experiment = smoothTraces(experiment, varargin)
% SMOOTHTRACES smooth traces to fix drift and other issues.
%
% USAGE:
%    experiment = smoothTraces(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: smoothTracesOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = smoothTraces(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: smooth traces
% parentGroups: fluorescence: basic
% optionsClass: smoothTracesOptions
% requiredFields: rawT, rawTraces
% producedFields: traces, t, baseLine

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(smoothTracesOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.traceFixCorrection = [];
params.traceFixCorrectionOptions = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Smoothing traces');
%--------------------------------------------------------------------------

switch params.tracesType
  case 'raw'
    experiment = loadTraces(experiment, 'raw');
    traces = experiment.rawTraces-params.offsetParameter;
    t = experiment.rawT;
  case 'denoised'
    experiment = loadTraces(experiment, 'rawTracesDenoised');
    traces = experiment.rawTracesDenoised-params.offsetParameter;
    t = experiment.rawTDenoised;
end

smoothingMethod = params.smoothingMethod;

nTraces = size(traces, 2);
nFrames = size(traces, 1);

smoothedTraces = zeros(nFrames, nTraces);
baseLine = zeros(nFrames, nTraces);


% Consistency checks
if(strcmpi(params.smoothingMethod, 'median filter') && verLessThan('matlab','9.0'))
  logMsg('Median filter can only be used with Matlab R2016a and above', 'e');
  barCleanup(params);
  return;
end
  
  
if(params.smoothingWindow > 0)
  dt = t(2)-t(1);
  smoothingWindow = floor(params.smoothingWindow/dt);
elseif(params.smoothingWindow == 0)
  smoothingWindow = 0;
else
  smoothingWindow = 0;
  logMsg('Invalid smoothing window length. Should be a positive double. Using default values', 'w');
end
for it = 1:nTraces
  neuronData = traces(:, it);

  if(~isempty(params.traceFixCorrection))
    invalidPoints = params.traceFixCorrection;
    newInvalidPoints = [];
    % Do the traceFix Correction
    if(length(experiment.traceFixerOptionsCurrent.expansionInterval) == 2)
      N = length(experiment.traceFixerOptionsCurrent.expansionInterval(1):experiment.traceFixerOptionsCurrent.expansionInterval(2));
    else
      N = length(experiment.traceFixerOptionsCurrent.expansionInterval);
    end
    baseLineLevel = round(N*0.5);
    tt = invalidPoints';
    x = diff(tt)==1;
    f = find([false,x]~=[x,false]);
    g = find(f(2:2:end)-f(1:2:end-1) + 1 >= N);
    first_t = tt(f(2*g-1));
    last_t = tt(f(2*g));
    correctedT = neuronData;
    for it3 = 1:length(first_t)
      prevBase = mean(correctedT((first_t(it3)-baseLineLevel):(first_t(it3))));
      nextBase = mean(correctedT(last_t(it3):(last_t(it3)+baseLineLevel)));

      [~, closestFirsT] = min(abs(correctedT(first_t(it3):(first_t(it3)+baseLineLevel)) - prevBase));
      closestFirsT = closestFirsT + first_t(it3) - 1;

      [~, closestLastT] = min(abs(correctedT((last_t(it3)-baseLineLevel):last_t(it3)) - nextBase));
      closestLastT = closestLastT + last_t(it3) - baseLineLevel - 1;
      newInvalidPoints = [newInvalidPoints, closestFirsT:closestLastT]; 
    end
    params.traceFixCorrection = newInvalidPoints(:);
  end
  neuronDataSmoothed = applySmoothing(t, neuronData, smoothingMethod, smoothingWindow);
  try
    if(strcmpi(params.polyFitType, 'spline fitting percentile correction'))
      params.avgT = experiment.avgT;
      params.avgF = experiment.avgTrace;
    end
    [neuronDataCorrected, neuronDataBaseline] = applyCorrection(neuronDataSmoothed, t, params);
  catch ME
    logMsg(ME.message, 'e');
    logMsg('Something went wrong while applying baseline correction', 'e');
    barCleanup(params);
    return;
  end

  smoothedTraces(:, it) = neuronDataCorrected;
  baseLine(:, it) = neuronDataBaseline;

  if(params.pbar > 0)
    ncbar.update(it/nTraces);
  end
end

experiment.traces = smoothedTraces;
experiment.t = t;
if(params.storeBaseline)
  experiment.baseLine = baseLine;
end
experiment.saveBigFields = true; % So the traces are saved

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
