function experiment = processMovementSignal(experiment, varargin)
% PROCESSMOVEMENTSIGNAL processes movement data into a binary signal to
% detect up and down regulation
%
% USAGE:
%    experiment = processMovementSignal(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: processMovementOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = processMovementSignal(experiment)
%
% Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: movement processing
% parentGroups: behavior: basic
% optionsClass: processMovementOptions
% requiredFields: t, motion_energy_glob
% producedFields: movement, movementBinned, movementBurstStructure, interpMotion

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(processMovementOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.movement = [];
params.processMovementOptions = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Processing movement data');
%--------------------------------------------------------------------------

% Check consistency of data 
% All dt should be within 1 ms of each other
if(any(diff(experiment.interframe_int)*1e6 >1)) 
  logMsg(sprintf('Incosistency detected on experiment: %s.', experiment.name),'w');
  incosistencyFlag = true;

  figure;
  plot(cumsum(experiment.interframe_int*1e3),experiment.interframe_int*1e6,'.')
  xlabel('time (s)');
  ylabel('interframe interavl (ms)');
  title(sprintf('Movement consistency check on: %s', experiment.name), 'interpreter', 'none');
else
  incosistencyFlag = false;
end

% Let's interpolate always given the delay
interpMotion = interp1(experiment.tstamps*1e3, double(experiment.motion_energy_glob), experiment.t, 'linear', 0);

% The plots
if(params.showFigure | incosistencyFlag)
  visible = 'on';
else
  visible = 'off';
end
hFig = figure('Name', [experiment.name ' movement interpolation'], 'NumberTitle', 'off', 'Visible', visible);

hold on;
plot(experiment.tstamps*1e3, experiment.motion_energy_glob);
plot(experiment.t, interpMotion);
xlabel('time (s)');
ylabel('movement signal');
title(sprintf('Movement interpolation on: %s', experiment.name), 'interpreter', 'none');
legend('before interp', 'after interp');
if(incosistencyFlag)
  set(gcf,'Color',[1 0 0]*0.75);
end

hFig.Position = [hFig.Position(1:2) params.figureSize(:)'];
ui = uimenu(hFig, 'Label', 'Export');
uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_movementInterpolation']});

if(params.saveFigure)
  switch params.saveBaseFolder
    case 'experiment'
      baseFolder = experiment.folder;
    case 'project'
      baseFolder = [experiment.folder '..' filesep];
  end
  if(~exist(baseFolder, 'dir'))
    mkdir(baseFolder);
  end
  figFolder = [baseFolder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
  export_fig([figFolder, experiment.name, '_movementInterpolation', params.saveFigureTag, '.', params.saveFigureType], ...
             sprintf('-r%d', params.saveFigureResolution), ...
             sprintf('-q%d', params.saveFigureQuality));
end

if(strcmp(visible, 'off'))
  close(hFig);
end


experiment.interpMotion = interpMotion;


if(~isempty(params.subset))
  tmpFrames = round(params.subset*experiment.fps);
  firstFrame = tmpFrames(1);
  lastFrame = tmpFrames(2);
  if(firstFrame < 1)
      firstFrame = 1;
  end
  if(lastFrame > experiment.numFrames)
      lastFrame = experiment.numFrames;
  end
  if(params.verbose)
    logMsg(sprintf('Subset not empty. Only using frames in the range (%d, %d)', firstFrame, lastFrame));
  end
  validFrames = firstFrame:lastFrame;
else
  validFrames = 1:min(length(experiment.rawT), length(interpMotion));
end

selectedT = experiment.rawT(validFrames);
dt = 1/experiment.fps;

movement = double(interpMotion(validFrames));
if(params.filterWindow > 0)
  windowSize = ceil(params.filterWindow/dt);
  %movement = medfilt1((double(movement)), params.filterWindow);
  baseLine = movquant(movement(:), 0.2, 1000, 1, false, 'truncate')';
  movement = movement - baseLine;
  movCorr = movement;
  movCorr = (movCorr - median(movCorr))/mad(movCorr,1);
  movement = ewma(movement, 2/(windowSize+1), true);
end

switch params.zscore
  case 'robust'
    movement = (movement - median(movement))/mad(movement,1);
  case 'normal'
    movement = zscore(movement);
  case 'none'
  otherwise
    logMsg('Invalid z-score value. Using none instead.', 'w');
end

%dt = 1/experiment.fps;
%tv = 0.25;
%y = schmit t_trigger(motion, tv, tv);

[y, bursts] = detectBurstsSchmitt(experiment.rawT, movement, params.schmittThresholdType, params.schmittThresholds(1), params.schmittThresholds(2));
bursts.signal = y;

%lowFrames = find(y == 0);
%highFrames = find(y == 1);

experiment.movementBurstStructure = bursts;
experiment.movement = movement;
experiment.movementBinned = y;
experiment.movementFrames = validFrames;

if(params.showFigure)
  visible = 'on';
else
  visible = 'off';
end
hFig = figure('Name', [experiment.name ' movement detection'], 'NumberTitle', 'off', 'Visible', visible);

%ax = multigap_subplot(2, 1, 'margin_TB', [0.1 0.1], 'gap_C', 0.2, 'margin_TB', 0.15);
tiledlayout(2,1);
nexttile;
hold on;
origMov = interpMotion(validFrames);
plot(selectedT, origMov, 'Color', [0.7 0.7 0.7]);
if(~isempty(bursts) && isfield(bursts, 'frames') && ~isempty(bursts.frames))
  frames = bursts.frames;
  for i = 1:length(frames)
    plot(selectedT(frames{i}), origMov(frames{i}), 'LineWidth', 1);
  end
end
xlabel('time (s)');
ylabel('original movement signal');
title([experiment.name ' original movement'], 'interpreter', 'none');
ylim(prctile(double(interpMotion(validFrames)), [1 99]));
a1 = gca;

nexttile;
hold on;
%plot(selectedT, movCorr, 'Color', [0.8 0.8 0.8]);
plot(selectedT, movement, 'Color', [0.7 0.7 0.7]);
a2 = gca;
if(~isempty(bursts) && isfield(bursts, 'frames') && ~isempty(bursts.frames))
  frames = bursts.frames;
  for i = 1:length(frames)
    plot(selectedT(frames{i}), movement(frames{i}), 'LineWidth', 1);
  end
  burstThresholdLower = bursts.thresholds(1);
  burstThresholdUpper = bursts.thresholds(2);
    
  switch params.schmittThresholdType
    case 'relative'
      if(~isnan(burstThresholdUpper))
        avgMean = mean(movement);
        avgStd = std(movement);
        xl = xlim;
        plot(xl, [1,1]*(avgMean+burstThresholdUpper*avgStd), 'r--');
        plot(xl, [1,1]*(avgMean+burstThresholdLower*avgStd), 'b--');
      end
    case 'absolute'
      xl = xlim;
      plot(xl, [1,1]*(burstThresholdUpper), 'r--');
      plot(xl, [1,1]*(burstThresholdLower), 'b--');
  end
end
ylim(prctile(movement, [1 99]));
xlabel('time (s)');
ylabel('movement signal (a.u.)');
title([experiment.name ' processed movement'], 'interpreter', 'none');

set(gcf,'Color','w');
%pos = get(hFig, 'Position');
%pos(4) = pos(3)/((1+sqrt(5))/2);
%set(hFig, 'Position', pos);
hFig.Position = [hFig.Position(1:2) params.figureSize(:)'];
linkaxes([a1 a2], 'x');
ui = uimenu(hFig, 'Label', 'Export');
uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_movement']});

if(params.saveFigure)
  switch params.saveBaseFolder
    case 'experiment'
      baseFolder = experiment.folder;
    case 'project'
      baseFolder = [experiment.folder '..' filesep];
  end
  if(~exist(baseFolder, 'dir'))
    mkdir(baseFolder);
  end
  figFolder = [baseFolder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
  export_fig([figFolder, experiment.name, '_movement', params.saveFigureTag, '.', params.saveFigureType], ...
             sprintf('-r%d', params.saveFigureResolution), ...
             sprintf('-q%d', params.saveFigureQuality));
end

if(~params.showFigure)
  close(hFig);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end

%------------------------------------------------------------------------
function [y, burstStructure] = detectBurstsSchmitt(t, avgTrace, thresholdType, upperThreshold, lowerThreshold)
  switch thresholdType
    case 'relative'
      avgMean = mean(avgTrace);
      avgStd = std(avgTrace);
      y = schmitt_trigger(avgTrace, avgMean+lowerThreshold*avgStd, avgMean+upperThreshold*avgStd);
    case 'absolute'
      y = schmitt_trigger(avgTrace, lowerThreshold, upperThreshold);
      % For the reverse schmitt
      yr = schmitt_trigger(avgTrace(end:-1:1), lowerThreshold, upperThreshold);
      yr = yr(end:-1:1);
      y = y | yr;
  end
  avgTraceAbove = nan(size(avgTrace));
  avgTraceAbove(y == 1) = avgTrace(y == 1);

  split = SplitVec(y, 'equal', 'first');
  splitVals = SplitVec(y, 'equal');
  validSplit = find(y(split) == 1);

  burstDuration = zeros(length(validSplit), 1);
  burstAmplitude = zeros(length(validSplit), 1);
  burstStart = zeros(length(validSplit), 1);
  burstFrames = cell(length(validSplit), 1);
  for i = 1:length(validSplit)
    burstFrames{i} = split(validSplit(i)):(split(validSplit(i))+length(splitVals{validSplit(i)})-1);
    burstT = t(burstFrames{i});
    burstF = avgTraceAbove(burstFrames{i});
    burstDuration(i) = burstT(end)-burstT(1);
    burstStart(i) = burstT(1);
    burstAmplitude(i) = max(burstF);
    %plot(burstT, burstF, 'LineWidth', 2);
  end
  IBI = diff(burstStart);
  burstStructure = struct;
  burstStructure.duration = burstDuration;
  burstStructure.amplitude = burstAmplitude;
  burstStructure.start = burstStart;
  burstStructure.IBI = IBI;
  burstStructure.frames = burstFrames;
  burstStructure.thresholds = [lowerThreshold upperThreshold];
end


function y = ewma(x, alpha, x0_as_y0)
%EWMA Causal exponential smoother: y(t) = alpha*x(t) + (1-alpha)*y(t-1)
%   x  : vector or matrix (operates along first dimension)
%   alpha : scalar in (0,1]
%   x0_as_y0 (optional, default=true): initialize y(1)=x(1)
%
%   For matrices, smoothing is column-wise (down rows).
  arguments
      x {mustBeNumeric, mustBeNonempty}
      alpha (1,1) double {mustBeGreaterThan(alpha,0), mustBeLessThanOrEqual(alpha,1)}
      x0_as_y0 (1,1) logical = true
  end

  % Ensure column-wise operation
  wasRow = isvector(x) && size(x,1)==1;
  if wasRow
      x = x.'; % make column
  end

  b = alpha;
  a = [1, -(1-alpha)];

  if x0_as_y0
      % Initialize by offsetting the input so that y(1)=x(1)
      % Trick: run filter on (x - x(1)), then add x(1) back
      x1 = x(1,:);
      y = filter(b, a, x - x1) + x1;
  else
      % Default zero initial condition
      y = filter(b, a, x);
  end

  if wasRow
      y = y.'; % restore row shape
  end
end