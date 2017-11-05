function experiment = extractTraces(experiment, varargin)
% EXTRACTTRACES extract the traces from a given experiment and preselected
% ROI
%
% USAGE:
%    experiment = extractTraces(experiment)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: extractTracesOptions
%
% OUTPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% EXAMPLE:
%    experiment = extractTraces(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: extract traces
% parentGroups: fluorescence: basic
% optionsClass: extractTracesOptions
% requiredFields: ROI, fps, numFrames
% producedFields: rawT, rawTraces

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(extractTracesOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Extracting traces');
%--------------------------------------------------------------------------

ROI = experiment.ROI;

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
else
  firstFrame = 1;
  lastFrame = experiment.numFrames;
end
selectedFrames = firstFrame:lastFrame;

numFrames = length(selectedFrames);
traces = zeros(numFrames, length(ROI));


% Set the average function
switch params.averageType
  case 'mean'
    avgFunc = @mean;
  case 'median'
    avgFunc = @median;
  otherwise
    avgFunc = @mean;
end

switch params.movieToPreprocess
  case 'standard'
    [fid, experiment] = openVideoStream(experiment);
  case 'denoised'
    experiment = loadTraces(experiment, 'denoisedData');
    denoisedBlocksPerFrame = [arrayfun(@(x)x.frames(1), experiment.denoisedData)', arrayfun(@(x)x.frames(2), experiment.denoisedData)'];
end

signCoincidence = zeros(length(selectedFrames)-1, 1);
prevFrame = [];
numPixels = experiment.width*experiment.height;
for i = 1:length(selectedFrames)
  switch params.movieToPreprocess
    case 'standard'
      currentFrame = double(getFrame(experiment, selectedFrames(i), fid));
    case 'denoised'
      currentFrame = double(getDenoisedFrame(experiment, selectedFrames(i), denoisedBlocksPerFrame));
  end
  if(~isempty(prevFrame))
    positiveD = sum(sum(currentFrame-prevFrame > 0));
    negativeD = sum(sum(currentFrame-prevFrame < 0));
    %signCoincidence(i-1) = max(positiveD, numPixels-positiveD)/numPixels;
    signCoincidence(i-1) = abs(positiveD-negativeD)/numPixels;
  end
  for j = 1:length(ROI)
    traces(i, j) = avgFunc(currentFrame(ROI{j}.pixels));
  end
  % Do something with the frames
  if(params.pbar > 0)
    ncbar.update(i/numFrames);
  end
  prevFrame = currentFrame;
end
switch params.movieToPreprocess
  case 'standard'
    closeVideoStream(fid);
    t = (selectedFrames')/experiment.fps;
    experiment.rawTraces = traces;
    experiment.rawT = t;
  case 'denoised'
    t = (selectedFrames')/experiment.fps;
    experiment.rawTracesDenoised = traces;
    experiment.rawTDenoised = t;
end
experiment.signCoincidence = signCoincidence;
experiment.saveBigFields = true; % So the traces are saved

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
