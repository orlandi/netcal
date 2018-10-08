function experiment = smoothTracesV2(experiment, varargin)
% SMOOTHTRACESV2 improved and simplified trace smoothing for difficult traces
%
% USAGE:
%    experiment = smoothTracesDifficult(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: smoothTracesV2Options
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = smoothTracesV2(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also extractTraces

% DEBUG EXPERIMENT PIPELINE
% name: smooth traces v2
% parentGroups: fluorescence: basic
% optionsClass: smoothTracesV2Options
% requiredFields: rawT, rawTraces
% producedFields: traces, t, baseLine

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(smoothTracesV2Options, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Smoothing traces');
%--------------------------------------------------------------------------
originalExperiment = experiment;

switch params.movieToPreprocess
  case 'standard'
    experiment = loadTraces(experiment, 'raw');
    traces = experiment.rawTraces;
    t = experiment.rawT;
  case 'denoised'
    experiment = loadTraces(experiment, 'rawTracesDenoised');
    traces = experiment.rawTracesDenoised;
    t = experiment.rawTDenoised;
end


nTraces = size(traces, 2);
nFrames = size(traces, 1);

smoothedTraces = zeros(nFrames, nTraces);
baseLine = zeros(nFrames, nTraces);
ROIid = getROIid(experiment.ROI);


% That's for the loess
smoothLength = 100;

if(params.smoothingWindow > 0)
  dt = t(2)-t(1);
  smoothingWindow = floor(params.smoothingWindow/dt);
elseif(params.smoothingWindow == 0)
  smoothingWindow = 5;
else
  smoothingWindow = 5;
  logMsg('Invalid smoothing window length. Should be a positive double. Using default values', 'w');
end
if(params.splineSmoothingParam == 0)
  splineSmoothingParam = 1e-4;
else
  splineSmoothingParam = params.splineSmoothingParam;
end

if(params.debug)
  nTraces = 1;
  selectedTraces = find(ROIid == params.debugTrace);
else
  selectedTraces = 1:size(traces, 2);
end
blockLength = params.splineDivisionLength;
for its = selectedTraces
  signal = traces(:, its);
  originalSignal = signal;
  signal = smooth(signal, smoothLength, 'loess');
  
  blockEdges = 1:round(blockLength*experiment.fps):length(t);

  for it = 1:(length(blockEdges)-1)
    [~, valid] = min(signal(blockEdges(it):blockEdges(it+1)));
    blockEdges(it) = blockEdges(it)+valid-1;
  end
  blockEdges = blockEdges(1:end-1);
  if(blockEdges(1) > round(blockLength*experiment.fps)/2)
    blockEdges = [1, blockEdges];
  end
  if(blockEdges(end) <= length(t)-round(blockLength*experiment.fps)/2)
    blockEdges = [blockEdges, length(t)];
  end

  itBlock = 1;
  done = false;
  blockFrameLength = round(blockLength*experiment.fps);
  while(~done)
    try
      [~, valid] = min(signal(round(itBlock(end)+blockFrameLength/2):round(itBlock(end)+3*blockFrameLength/2)));
      valid = valid + round(itBlock(end)+blockFrameLength/2) - 1;
    catch
      done = true;
      valid = length(t);
    end
    itBlock = [itBlock, valid];
  end
  F0 = signal(itBlock(1));
  
  splineBlockMeanT = t(itBlock);
  splineBlockSignal = signal(itBlock);
  % First and last blocks do not use the loess filtering, original data instead
  if(itBlock(1) < 10)
    splineBlockSignal(1) = originalSignal(1);
  end
  if(itBlock(end) > length(t)-10)
    splineBlockSignal(end) = originalSignal(end);
  end
  % Now the correction
  % Do the fitting and get the baseline
  if(params.splineKinkCorrection)
    done = false;
  else
    done = true;
  end
  iters = 0;
  splineCorrection = true;
  while(~done && iters < 1)
    [curve, gof, out] = fit(splineBlockMeanT,splineBlockSignal,'smoothingspline', 'SmoothingParam', splineSmoothingParam);
    %[curve, gof, out] = fit(splineBlockMeanT,splineBlockSignal,'smoothingspline');
    baseLineTmp = feval(curve,t);
    signalCorrected = signal - baseLineTmp;
    if(~splineCorrection)
      done = true;
    else
      invalid = find(baseLineTmp > signal);
      if(isempty(invalid))
        done = true;
      else
        %closestList = [];
  %       for it = 1:length(invalid)
  %         [~, closest] = sort(abs(splineBlockMeanTframes-invalid(it)));
  %         closestList = [closestList; closest(1:2)];
  %         %closestList = [closestList; closest(1)];
  %       end
        % Instead, with blocks
        
        newPoints = invalid;
        % Resimplify
        T = clusterdata(t(newPoints), 'cutoff', 15, 'criterion', 'distance', 'distance','euclidean');
        uniqueT = unique(T);
        fullInvalid = [];
        for it = 1:length(uniqueT)
          valid = find(T == uniqueT(it));
          [~, idx] = min(abs(signal(valid)-mean(signal(valid))));
          invalid = valid;
          invalid(idx) = [];
          fullInvalid = [fullInvalid; invalid(:)];
        end
        newPoints(fullInvalid) = [];
        
        for it = 1:length(newPoints)
          splineBlockMeanT = [splineBlockMeanT(:); t(newPoints)];
          splineBlockSignal = [splineBlockSignal(:); signal(newPoints)*0.99];
          ar = [splineBlockMeanT(:), splineBlockSignal(:)];
          ar = sortrows(ar, 1);
          splineBlockMeanT = ar(:,1);
          splineBlockSignal = ar(:,2);
        end
        % Resimplify blocks
        T = clusterdata(splineBlockMeanT, 'cutoff', 15, 'criterion', 'distance', 'distance','euclidean');
        uniqueT = unique(T);
        fullInvalid = [];
        for it = 1:length(uniqueT)
          valid = find(T == uniqueT(it));
          [~, idx] = min(splineBlockSignal(valid));
          invalid = valid;
          invalid(idx) = [];
          fullInvalid = [fullInvalid; invalid(:)];
        end
        splineBlockMeanT(fullInvalid) = [];
        splineBlockSignal(fullInvalid) = [];
        %closestList = unique(closestList);
        %splineBlockSignal(closestList) = splineBlockSignal(closestList)*0.99;
        iters = iters + 1;
      end
    end
  end

  curve = fit(splineBlockMeanT, splineBlockSignal, 'smoothingspline', 'SmoothingParam', splineSmoothingParam);
  y = feval(curve, t);
  switch params.dataNormalization
    case '100x(F-F0)/F0'
      smoothedTraces(:, its) = 100*smooth(traces(:, its)-y, smoothingWindow)/F0;
    case '(F-F0)/F0'
      smoothedTraces(:, its) = smooth(traces(:, its)-y, smoothingWindow)/F0;
    case 'none'
      smoothedTraces(:, its) = smooth(traces(:, its)-y, smoothingWindow);
  end
  baseLine(:, its) = y;

  
  % Now another baseline correction
  switch params.baseLineCorrection
    case 'mean'
      signalCorrected = signalCorrected-mean(signalCorrected);
    case 'block'
      validElementsPerBlock = floor(params.blockDivisionFraction*length(t));
      if(params.blockDivisionFraction > 1)
        logMsg('blockDivisionFraction should be <= 1', 'e');
        return;
      end
      if(validElementsPerBlock == 0)
        logMsg('Not enough elements per block for baseline correction. Try increasing the blockDivisionFraction', 'e');
        return;
      end
      sortedBlockSignal = sort(smoothedTraces(:, its));
      smoothedTraces(:, its) = smoothedTraces(:, its) - sortedBlockSignal(validElementsPerBlock);
    otherwise
      % Nothing
  end

  if(params.pbar > 0)
    ncbar.update(its/nTraces);
  end
end
if(params.debug)
  figure;
  subplot(2, 1, 1);
  plot(t, traces(:, its));
  hold on;
  plot(t, smooth(traces(:, its), smoothLength, 'loess'));
  
  plot(splineBlockMeanT, splineBlockSignal, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
  curve = fit(splineBlockMeanT, splineBlockSignal, 'smoothingspline', 'SmoothingParam', 0.001);
  y = feval(curve, t);
  plot(t, y, 'k');

  xlim([0 max(t)]);

  subplot(2, 1, 2);
  plot(t, smoothedTraces(:, params.debugTrace));
  hold on;
  xlim([0 max(t)]);
  xl = xlim;
  plot(xl, [0 0],'k');
  barCleanup(params);
  experiment = originalExperiment;
  return;
end
experiment.traces = smoothedTraces;
experiment.t = t;
if(params.storeBaseline)
  experiment.baseLine = baseLine;
elseif(isfield(experiment, 'baseLine'))
  experiment = rmfield(experiment, 'baseLine');
end
experiment.saveBigFields = true; % So the traces are saved

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
