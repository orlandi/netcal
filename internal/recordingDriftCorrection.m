function experiment = recordingDriftCorrection(experiment, varargin)
% RECORDINGDRIFTCORRECTION Corrects any drift that appeared on a recording (sample slowly moving around)
%
% USAGE:
%   experiment = recordingDriftCorrection(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class recordingDriftCorrectionOptions
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = recordingDriftCorrection(experiment, recordingDriftCorrectionOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also recordingDriftCorrectionOptions

% EXPERIMENT PIPELINE
% name: drift correction
% parentGroups: fluorescence: basic
% optionsClass: recordingDriftCorrectionOptions
% requiredFields: fps, numFrames, width, height
% producedFields: affineTransform
  
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(recordingDriftCorrectionOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Computing drift correction');
%--------------------------------------------------------------------------

if(isfield(experiment, 'affineTransform'))
  try
    experiment.width = experiment.realWidth;
    experiment.height = experiment.realHeight;
  end
end
experiment.affineTransformEnabled = false;
if(params.referenceFrame > experiment.numFrames)
  logMsg('Reference frame is not valid. Using the first one instead', 'w');
  params.referenceFrame = 1;
end
% Before we start, make sure that no transformation exists
experiment.affineTransformEnabled = false;

frameAvg = params.keyFrameAverage;
if(isempty(frameAvg) || frameAvg < 1)
  frameAvg = 1;
end
numberKeyFrames = params.numberKeyFrames;
if(isempty(numberKeyFrames) || numberKeyFrames < 1 || numberKeyFrames > experiment.numFrames)
  selFrames = 1:(experiment.numFrames-(frameAvg-1));
else
  selFrames = floor(linspace(1, experiment.numFrames-(frameAvg-1), numberKeyFrames));
end

tList = zeros(3, 3, length(selFrames));

[optimizer,metric] = imregconfig('multimodal');
%optimizer.InitialRadius = optimizer.InitialRadius/3.5;
optimizer.InitialRadius = optimizer.InitialRadius;

fID = openVideoStream(experiment);

% Let's get the first frame
tmpFrame = zeros(experiment.height, experiment.width, frameAvg);

for it = 1:frameAvg
  tmpFrame(:,:, it) = getFrame(experiment, params.referenceFrame+it-1, fID);
end
framePre = mean(tmpFrame, 3);


mask = zeros(experiment.height, experiment.width);
Rfixed = imref2d([experiment.height experiment.width]);
for it = 1:length(selFrames)
  curFrame = selFrames(it);
  tmpFrame = zeros(experiment.height, experiment.width, frameAvg);
  for it2 = 1:frameAvg
    tmpFrame(:,:, it2) = getFrame(experiment, curFrame+it2-1, fID);
  end
  framePost = mean(tmpFrame, 3);
  switch params.transformationType
    case 'subpixelDFT'
      [output, ~] = dftregistration(fft2(framePre),fft2(framePost), params.subPixelResolution);
      tList(:, :, it) = [1 0 0;0 1 0;output(4) output(3) 1];
      tformSimilarity = affine2d(tList(:, :, it));
      mask = mask+imwarp(double(framePre), tformSimilarity, 'OutputView', Rfixed, 'FillValues', NaN);
    otherwise
      if(it > 1 && params.iterativeAlignment)
        tformSimilarity = imregtform(framePost, framePre, params.transformationType, optimizer, metric, 'InitialTransformation', tformSimilarity);
      else
        tformSimilarity = imregtform(framePost, framePre, params.transformationType, optimizer, metric);
      end
      tList(:, :, it) = tformSimilarity.T;
      mask = mask+imwarp(double(framePre), tformSimilarity, 'OutputView', Rfixed, 'FillValues', NaN);
  end
  if(params.pbar > 0)
    ncbar.update(it/length(selFrames));
  end
end
experiment.affineTransformationType = params.transformationType;
closeVideoStream(fID);


% Try to make the mask rectangular
invalidC = find(sum(isnan(mask)) > length(mask)*0.3);
invalidR = find(sum(isnan(mask),2) > length(mask)*0.3);
mask(~isnan(mask)) = 1;
% Add 1 to both sides
invalidC = unique([invalidC, invalidC+1, invalidC-1]);
invalidR = unique([invalidR, invalidR+1, invalidR-1]);

invalidC(invalidC < 1) = [];
invalidR(invalidR < 1) = [];
invalidC(invalidC > size(mask, 2)) = [];
invalidR(invalidR > size(mask, 1)) = [];
validR = setdiff(1:size(mask, 1), invalidR);
validC = setdiff(1:size(mask, 1), invalidC);
mask(invalidR, :) = 0;
mask(:, invalidC) = 0;
experiment.realWidth = experiment.width;
experiment.realHeight = experiment.height;
experiment.affineWidth = length(validC);
experiment.affineHeight = length(validR);
experiment.affineRefFrame = framePre;
experiment.affineInterpolationType = params.interpolationType;
experiment.affineType = params.transformationType;
experiment.affineSubPixelResolution = params.subPixelResolution;
experiment.validR = validR;
experiment.validC = validC;
experiment.validPixels = find(mask);
[mr,mc] = find(mask);
if(~isempty(setdiff(unique(mr), validR)) || ~isempty(setdiff(unique(mc), validC)))
  logMsg('Mask and valid pixels mismatch. There migth be something wrong with the associated area. I''ll try and fix it', 'w');
  experiment.validR = unique(mr);
  experiment.validC = unique(mc);
  experiment.affineWidth = length(experiment.validC);
  experiment.affineHeight = length(experiment.validR);
end
figure;imagesc(mask);colormap gray;title('Valid Region');

maxDisp = 0;
for it = 1:length(selFrames)
  xy = [0 0 1]*tList(:, :, it);
  maxDisp = max(maxDisp, sqrt(sum(xy(1:2).^2)));
end
maxDisp = sqrt(sum(maxDisp.^2));


experiment.affineTransformEnabled = params.enableResultingTransformation;
if(maxDisp >= params.minimumDisplacement && params.enableResultingTransformation)
  logMsg(sprintf('%s: Maximum displacement (%.2f pixels). Above threshold. Drift correction enabled', experiment.name, maxDisp));
  experiment.affineTransformEnabled = true;
  experiment.width = experiment.affineWidth;
  experiment.height = experiment.affineHeight;
elseif(maxDisp < params.minimumDisplacement && params.enableResultingTransformation)
  logMsg(sprintf('%s: Maximum displacement (%.2f pixels). Below threshold. Drift correction disabled', experiment.name, maxDisp));
  experiment.affineTransformEnabled = false;
  experiment.width = experiment.realWidth;
  experiment.height = experiment.realHeight;
else
  logMsg(sprintf('%s: Maximum displacement (%.2f pixels)', experiment.name, maxDisp));
end

if(params.plotTrajectory)
  figure;
  trajXYZ = zeros(length(selFrames), 3);
  for it = 1:length(selFrames)
    xy = [0 0 1]*tList(:, :, it);
    trajXYZ(it, :) = [-xy(1:2), selFrames(it)/experiment.fps];
  end
  plot3(trajXYZ(:, 2), trajXYZ(:, 1), trajXYZ(:, 3), 'o-');
  hold on;
  theta = linspace(0, 2*pi, 100);
  plot(maxDisp*cos(theta), maxDisp*sin(theta), 'b--');
  xlabel('x');
  ylabel('y');
  axis ij;
  box on;
  zlabel('t');
  view([0 90]);
  title('Driff trajectory');
end

if(params.plotFinalTransformation)
  figure;
  Rfixed = imref2d(size(framePre));
  movingRegisteredRigid = imwarp(framePost, tformSimilarity, 'OutputView', Rfixed);
  imshowpair(movingRegisteredRigid, framePre);
end

% So that's pretty much it
experiment.affineTransformFrames = selFrames;
experiment.affineTransform = tList;

    
%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
end
