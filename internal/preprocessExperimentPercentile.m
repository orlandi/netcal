function experiment = preprocessExperimentPercentile(experiment, varargin)
% PREPROCESSEXPERIMENTPERCENTILE Computes the average image using a given
% percentile instead of the mean using reservoir sampling
%
% USAGE:
%   experiment = preprocessExperimentPercentile(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class preprocessExperimentPercentileOptions
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = preprocessExperimentPercentile(experiment, preprocessExperimentPercentileOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also preprocessExperimentPercentileOptions

% EXPERIMENT PIPELINE
% name: preprocess experiment percentile
% parentGroups: fluorescence: basic
% optionsClass: preprocessExperimentPercentileOptions
% requiredFields: fps, numFrames, width, height
% producedFields: percentileImg
  
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(preprocessExperimentPercentileOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Preprocessing the experiment using percentiles');
%--------------------------------------------------------------------------


maxMemoryUsage = params.maxMemoryUsage;
p = params.percentile;

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
selectedFrames = firstFrame:lastFrame;

L = length(selectedFrames);

N = round(params.fracionFramesUsed*L);
chosenFrames = firstFrame+sort(randperm(L, N))-1;

if(experiment.bpp == 16)
  dataType = 'uint16';
elseif(bitDepth == 8)
  dataType = 'uint8';
elseif(bitDepth == 32)
  dataType = 'uint32';
else
  dataType = 'double';
end  
blockSize = floor(0.9*maxMemoryUsage/(N*experiment.bpp/8/1e9));
if(blockSize > experiment.width*experiment.height)
  blockSize = experiment.width*experiment.height;
end
blockIdx = 1:blockSize:(experiment.width*experiment.height);
if(blockIdx(end) < experiment.width*experiment.height)
  blockIdx = [blockIdx, experiment.width*experiment.height];
end
blockLength = diff(blockIdx)+1;
pList = zeros(experiment.width, experiment.height);
[fID, experiment] = openVideoStream(experiment);


for it1 = 1:length(blockLength)
  pixelList = blockIdx(it1):blockIdx(it1+1);
  rArray = zeros(blockLength(it1), N, dataType);
  
  for f = 1:N
    % There's a lot of overhead, since we are reading the whole frame
    rArray(:,f) = getFrame(experiment, chosenFrames(f), fID, pixelList);
    %cFrame = getFrame(experiment, chosenFrames(f), fID);
    %rArray(:, f) = cFrame(pixelList);
    if(params.pbar > 0)
      ncbar.update(f/N*1/length(blockLength)+(it1-1)/length(blockLength));
    end
  end
  % Now the percentiles
  blockPList = prctile(rArray, p, 2);
  pList(pixelList) = blockPList;
end
closeVideoStream(fID);
% If its a his file we need to transpose
[~, ~, fpc] = fileparts(experiment.handle);
if(strcmpi(fpc, '.his'))
  pList = pList';
end

experiment.percentileImg = pList;

% Now the plots
if(params.showImage)
  plotAvgImg(experiment);
end

% Now the exports
if(params.exportImage)
  if(experiment.bpp == 8)
    data = uint8(experiment.percentileImg);
  elseif(experiment.bpp == 16)
    data = uint16(experiment.percentileImg);
  else
    data = uint16(experiment.percentileImg);
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
  
  fileName = [figFolder experiment.name '_percentileImageRaw.' params.exportImageFormat];
  try
    imwrite(data, fileName, 'compression','lzw');
    if(params.verbose)
      logMsg(sprintf('Raw percentile image exported to: %s', fileName));
    end
  catch ME
    logMsg(ME.message, 'e');
    logMsg('There was a problem exporting the percentile image', 'e');
  end
  
  % Now auto corrected
  fileName = [figFolder experiment.name '_percentileImageAutoCorrected.' params.exportImageFormat];
  [minI, maxI] = autoLevelsFIJI(data, experiment.bpp);
  data(data < minI) = minI;
  data(data > maxI) = maxI;
  try
    imwrite(uint16((double(data)-minI)/(maxI-minI)), fileName, 'compression','lzw');
    if(params.verbose)
      logMsg(sprintf('Auto corrected percentile image exported to: %s', fileName));
    end
  catch
    logMsg(ME.message, 'e');
    logMsg('There was a problem exporting the percentile image', 'e');
  end
  
  % Now as the plot
  fileName = [figFolder experiment.name '_percentileImage.' params.exportImageFormat];
  hFig = plotAvgImg(experiment, 'off');
  try
    export_fig(fileName, '-nocrop', '-r300');
    if(params.verbose)
      logMsg(sprintf('Percentile image exported to: %s', fileName));
    end
  catch ME
    logMsg(ME.message, 'e');
    logMsg('There was a problem exporting the percentile image', 'e');
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
  if(experiment.bpp == 8)
    imgData = uint8(experiment.percentileImg);
  elseif(experiment.bpp == 16)
    imgData = uint16(experiment.percentileImg);
  else
    imgData = uint16(experiment.percentileImg);
  end
  hFig = figure('Name', 'Percentile fluorescence image autocorrected', 'NumberTitle', 'off', 'Visible', visible);
  imagesc(imgData);
  axis equal tight;
  [minI, maxI] = autoLevelsFIJI(imgData, experiment.bpp);
  caxis([minI maxI]);
  colormap(gray);
  colorbar;
  title('Percentile fluorescence image');
  set(gca,'XTick',[]);
  set(gca,'YTick',[]);

  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_percentileImage']});
end


end
