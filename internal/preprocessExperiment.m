function experiment = preprocessExperiment(experiment, varargin)
% PREPROCESSEXPERIMENT does a fast analysis to obtain the average image and
% trace across the whole recording
%
% USAGE:
%   experiment = preprocessExperiment(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class preprocessExperimentOptions
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = preprocessExperiment(experiment, preprocessExperimentOptions)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also preprocessExperimentOptions

% EXPERIMENT PIPELINE
% name: preprocess experiment
% parentGroups: fluorescence: basic
% optionsClass: preprocessExperimentOptions
% requiredFields: fps, numFrames, width, height
% producedFields: avgImg, intensityRange, avgT, avgTrace, avgTraceLower, avgTraceHigher 
  
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(preprocessExperimentOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Preprocessing the experiment');
%--------------------------------------------------------------------------

imgFormat = params.exportImageFormat;
figFormat = params.exportFigureFormat;

if(params.fast)
  frameGap = 10;
  logMsg('Fast mode enabled. Only analyzing 1 out of every 10 frames');
else
  frameGap = 1;
end

if(params.backgroundImageCorrection.active)
  try
    experiment.backgroundImageCorrectionMode = params.backgroundImageCorrection.mode;
    experiment.backgroundImage = imread(params.backgroundImageCorrection.file);
    switch params.backgroundImageCorrection.mode
      case 'substract'
        experiment.backgroundImageMultiplier = -1;
      case 'add'
        experiment.backgroundImageMultiplier = 1;
      case {'multiply', 'divide'}
        experiment.backgroundImage = double(experiment.backgroundImage)/double(max(experiment.backgroundImage(:)));
    end
  catch ME 
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    logMsg('Could not load background image. Disabling the background correction', 'e');
    experiment.backgroundImageCorrection = false;
  end
  experiment.backgroundImageCorrection = true;
else
  experiment.backgroundImageCorrection = false;
end

if(~isempty(params.subset) && numel(params.subset) == 2)
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
    logMsg(sprintf('Subset not empty. Only analyzing frames in the range (%d,%d)', firstFrame, lastFrame));
  end
else
  firstFrame = 1;
  lastFrame = experiment.numFrames;
  if(params.verbose)
    logMsg(sprintf('Subset empty or invalid. Using all %d frames', lastFrame));
  end
end
selectedFrames = firstFrame:frameGap:lastFrame;

numFrames = length(selectedFrames);
avgTrace = zeros(numFrames, 1);

if(params.computeLowerPercentileTrace)
  avgTraceLower = zeros(numFrames, 1);
  lowerPercentilePixel = round(experiment.height*experiment.width/100*params.lowerPercentile);
  if(lowerPercentilePixel < 1)
    lowerPercentilePixel = 1;
  end
end

if(params.computeHigherPercentileTrace)
  avgTraceHigher = zeros(numFrames, 1);
  higherPercentilePixel = round(experiment.height*experiment.width/100*params.higherPercentile);
  if(higherPercentilePixel < 1)
    higherPercentilePixel = 1;
  end
end

minIntensity = inf;
maxIntensity = -inf;
avgImg = zeros(experiment.height, experiment.width);

switch params.movieToPreprocess
  case 'standard'
    [experiment, success] = precacheHISframes(experiment);
    [fID, experiment] = openVideoStream(experiment);
    if(isempty(fID) || fID <= 0)
      logMsg('There was a problem opening the video stream', 'e');
      return;
    end
  case 'denoised'
    experiment = loadTraces(experiment, 'denoisedData');
    denoisedBlocksPerFrame = [arrayfun(@(x)x.frames(1), experiment.denoisedData)', arrayfun(@(x)x.frames(2), experiment.denoisedData)'];
end


% Calcualte the averages
for i = 1:numFrames
  switch params.movieToPreprocess
    case 'standard'
      currentFrame = double(getFrame(experiment, selectedFrames(i), fID));
    case 'denoised'
      currentFrame = getDenoisedFrame(experiment, selectedFrames(i), denoisedBlocksPerFrame);
  end
    
  if(params.medianFilter)
      currentFrame = currentFrame - medfilt2(currentFrame, [1 1]*params.medianFilterSize);
  end
  avgImg = avgImg + currentFrame;

  minIntensity = min([minIntensity currentFrame(:)']);
  maxIntensity = max([maxIntensity currentFrame(:)']);
  avgTrace(i) = mean(currentFrame(:));
  if(params.computeLowerPercentileTrace || params.computeHigherPercentileTrace)
    sortedIntensities = sort(currentFrame(:));
  end
  if(params.computeLowerPercentileTrace)
    avgTraceLower(i) = mean(sortedIntensities(1:lowerPercentilePixel));
  end
  if(params.computeHigherPercentileTrace)
    avgTraceHigher(i) = mean(sortedIntensities(higherPercentilePixel:end));
  end
  if(params.pbar > 0)
    ncbar.update(i/numFrames);
  end
end
if(params.verbose)
  logMsg(sprintf('Intensity range: [%d %d]\n', minIntensity, maxIntensity));
end

avgImg = avgImg/length(selectedFrames);
intensityRange = [minIntensity maxIntensity];
t = selectedFrames'/experiment.fps;

switch params.movieToPreprocess
  case 'standard'
    closeVideoStream(fID);
    experiment.avgImg = avgImg;
  case 'denoised'
    experiment.avgImgDenoised = avgImg;
end


experiment.intensityRange = intensityRange;
experiment.avgT = t;
experiment.avgTrace = avgTrace;
if(params.computeLowerPercentileTrace)
  experiment.avgTraceLower = avgTraceLower;
end
if(params.computeHigherPercentileTrace)
  experiment.avgTraceHigher = avgTraceHigher;
end
% Now the plots
if(params.showAverageImage)
  plotAvgImg(experiment);
end

if(params.showAverageTrace)
  plotAvgTrace(experiment);
  if(params.computeLowerPercentileTrace)
    plotAvgTrace(experiment, 'on', experiment.avgTraceLower, 'lower');
  end
  if(params.computeHigherPercentileTrace)
    plotAvgTrace(experiment, 'on', experiment.avgTraceHigher, 'higher');
  end
end

% Now the exports
if(params.exportAverageImage)
  if(experiment.bpp == 8)
    data = uint8(experiment.avgImg);
  elseif(experiment.bpp == 16)
    data = uint16(experiment.avgImg);
  else
    data = uint16(experiment.avgImg);
  end
  % First the raw avg image
  
  if(~exist(experiment.folder, 'dir'))
    mkdir(experiment.folder);
  end
  dataFolder = [experiment.folder 'data' filesep];
  if(~exist(dataFolder, 'dir'))
    mkdir(dataFolder);
  end
  figFolder = [experiment.folder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
  
  switch params.movieToPreprocess
    case 'standard'
      fileName = [figFolder experiment.name '_averageImageRaw.' imgFormat];
    case 'denoised'
      fileName = [figFolder experiment.name '_averageImageDenoisedRaw.' imgFormat];
  end
  
  try
    imwrite(data, fileName, 'compression','lzw');
    if(params.verbose)
      logMsg(sprintf('Raw average image exported to: %s', fileName));
    end
  catch ME
    logMsg(ME.message, 'e');
    logMsg('There was a problem exporting the average image', 'e');
  end
  
  % Now auto corrected
  switch params.movieToPreprocess
    case 'standard'
      fileName = [figFolder experiment.name '_averageImageAutoCorrected.' imgFormat];
    case 'denoised'
      fileName = [figFolder experiment.name '_averageImageDenoisedAutoCorrected.' imgFormat];
  end
  
  [minI, maxI] = autoLevelsFIJI(data, experiment.bpp);
  data(data < minI) = minI;
  data(data > maxI) = maxI;
  try
    imwrite(uint16((double(data)-minI)/(maxI-minI)), fileName, 'compression','lzw');
    if(params.verbose)
      logMsg(sprintf('Auto corrected average image exported to: %s', fileName));
    end
  catch
    logMsg(ME.message, 'e');
    logMsg('There was a problem exporting the average image', 'e');
  end
  
  % Now as the plot
  switch params.movieToPreprocess
    case 'standard'
      fileName = [figFolder experiment.name '_averageImage.' imgFormat];
    case 'denoised'
      fileName = [figFolder experiment.name '_averageImageDenoised.' imgFormat];
  end
  
  hFig = plotAvgImg(experiment, 'off');
  try
    export_fig(fileName, '-nocrop', '-r300');
    if(params.verbose)
      logMsg(sprintf('Average image exported to: %s', fileName));
    end
  catch ME
    logMsg(ME.message, 'e');
    logMsg('There was a problem exporting the average image', 'e');
  end
  close(hFig);
end

if(params.exportAverageTrace)
  if(~exist(experiment.folder, 'dir'))
    mkdir(experiment.folder);
  end
  dataFolder = [experiment.folder 'data' filesep];
  if(~exist(dataFolder, 'dir'))
    mkdir(dataFolder);
  end
  figFolder = [experiment.folder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
  
  fileName = [figFolder experiment.name '_averageTrace.' figFormat];
  try
    hFig = plotAvgTrace(experiment, 'off');
  catch ME
    logMsg(ME.message, 'e');
    logMsg('There was a problem plotting the average trace', 'e');
  end
  try
    export_fig(fileName, '-nocrop', '-r300');
    if(params.verbose)
      logMsg(sprintf('Average trace exported to: %s', fileName));
    end
  catch ME
    logMsg(ME.message, 'e');
    logMsg('There was a problem exporting the average trace', 'e');
  end
  
  if(params.computeLowerPercentileTrace)
    fileName = [figFolder experiment.name '_loweTrace.' figFormat];
    hFig2 = plotAvgTrace(experiment, 'off', experiment.avgTraceLower, 'lower');
    try %#ok<TRYNC>
      export_fig(fileName, '-nocrop', '-r300')
    end
    close(hFig2);
  end
  if(params.computeHigherPercentileTrace)
    fileName = [figFolder experiment.name '_higherTrace.' figFormat];
    hFig2 = plotAvgTrace(experiment, 'off', experiment.avgTraceHigher, 'higher');
    try %#ok<TRYNC>
      export_fig(fileName, '-nocrop', '-r300')
    end
    close(hFig2);
  end
  
  close(hFig);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function hFig = plotAvgImg(experiment, visible)
  if(nargin < 2)
    visible = 'on';
  end
  
  switch params.movieToPreprocess
    case 'standard'
      if(experiment.bpp == 8)
        imgData = uint8(experiment.avgImg);
      elseif(experiment.bpp == 16)
        imgData = uint16(experiment.avgImg);
      else
        imgData = uint16(experiment.avgImg);
      end
      hFig = figure('Name', 'Average fluorescence image autocorrected', 'NumberTitle', 'off', 'Visible', visible);
    case 'denoised'
      if(experiment.bpp == 8)
        imgData = uint8(experiment.avgImgDenoised);
      elseif(experiment.bpp == 16)
        imgData = uint16(experiment.avgImgDenoised);
      else
        imgData = uint16(experiment.avgImgDenoised);
      end
      hFig = figure('Name', 'Average fluorescence image denoised autocorrected', 'NumberTitle', 'off', 'Visible', visible);
  end
  
  imagesc(imgData);
  axis equal tight;
  [minI, maxI] = autoLevelsFIJI(imgData, experiment.bpp);
  caxis([minI maxI]);
  colormap(gray);
  colorbar;
  title('Average fluorescence image');
  set(gca,'XTick',[]);
  set(gca,'YTick',[]);

  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_averageImage']});
end

%--------------------------------------------------------------------------
function hFig = plotAvgTrace(experiment, visible, trace, type)
  if(nargin < 2)
    visible = 'on';
  end
  if(nargin < 3)
    trace = experiment.avgTrace;
  end
  if(nargin < 4)
    type = 'average';
  end
  hFig = figure('Name', [type 'fluorescence trace'], 'NumberTitle', 'off', 'Visible', visible);
  plot(experiment.avgT, trace);
  xlabel('time (s)');
  ylabel('avg fluorescence (a.u.)');
  x_range = max(experiment.avgT)-min(experiment.avgT);
  y_range = max(trace)-min(trace);
  xlim([min(experiment.avgT)-x_range*0.01 max(experiment.avgT)+x_range*0.01]);
  ylim([min(trace)-y_range*0.01 max(trace)+y_range*0.01]);
  box on;
  title([type ' fluorescence trace']);
  set(gcf,'Color','w');
  pos = get(hFig, 'Position');
  pos(4) = pos(3)/((1+sqrt(5))/2);
  set(hFig, 'Position', pos);

  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_' type 'Trace']});
end

end
