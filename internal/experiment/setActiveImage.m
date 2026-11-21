function experiment = setActiveImage(experiment, varargin)
% SETACTIVEIMAGE Sets the active image. This will be the default image NETCAL uses when needed (usually for viewing the recording, defining ROis, etc)
%
% USAGE:
%   experiment = setActiveImage(experiment, options)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% INPUT optional arguments:
%   options - object from class setActiveImageOptions
%
% INPUT optional arguments ('key' followed by its value):
%   gui - handle of the external GUI
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = setActiveImage(experiment, setActiveImageOptions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also setActiveImageOptions

% EXPERIMENT PIPELINE
% name: set Active Image
% parentGroups: fluorescence:basic, misc
% optionsClass: setActiveImageOptions
% requiredFields: width, height
% producedFields: avgImg
  
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(setActiveImageOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Setting active image');
%--------------------------------------------------------------------------

% If the original never existed, but we have one average image, set it as
% the original
if(~isfield(experiment, 'avgImgOriginal') && isfield(experiment, 'avgImg'))
  experiment.avgImgOriginal = experiment.avgImg;
end

switch params.selection
  case 'average fluorescence'
    if(isfield(experiment, 'avgImgOriginal'))
      experiment.avgImg = experiment.avgImgOriginal;
    end
  case'external file'
    newImg = imread(params.externalFile);
    % Check for correct size
    if(size(newImg, 1) ~= experiment.height || size(newImg,2) ~= experiment.width)
      logMsg(sprintf('Cannot use file %s. Size mismatch. Expected WxH: %dx%d - Found: %dx%d', params.externalFile, experiment.width, experiment.height, size(newImg, 2), size(newImg, 1)), 'e');
    else
      % Check for grayscale
      if(size(newImg, 3))
        logMsg('RGB image found. Converting to grayscale', 'w');
        newImg = rgb2gray(newImg);
      end
      % Check for file type
      if(isfield(experiment, 'avgImg'))
        logMsg(sprintf('Class mismatch. Expected: %s - Found %s . Use at your own risk', class(experiment.avgImg), class(newImg)), 'w');
      end
      experiment.avgImg = newImg;
    end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

