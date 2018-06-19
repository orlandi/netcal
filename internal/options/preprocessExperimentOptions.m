classdef preprocessExperimentOptions < baseOptions
% PREPROCESSEXPERIMENTOPTIONS ### Preprocess experiment
% This is usually the first step to perform after importing a new
% experiment. Its main purpose is to go across all the frames and compute
% several observables. The main ones are:
% - **Average trace:** frame-averaged fluorescence intensity (useful to see
% drift and global behavior of the system).
% - **Average image:** time-averaged fluorescence intensity (useful to get a
% clear picture of the recording. This is the one you will be using to
% select the regions of interest later on).
%
% Mostof the options below are pretty self explanatory. The ones that ou
% will typically use (or care about) are:
% - **fast:** if set to true, it will only use one out of every 10 frames
% to get the averages. If your recording does't have a lot of noise, this
% will speed up everything substantially.
% - **subset:** To only compute the averages using a temporal subset of the
% recording. This is particuarly useful when you are applying drugs,
% chemicals and things like that, and you only want to use the first X
% seconds to get a nice average image.
% - **computeLowerPercentileTrace:** this will compute an additional
% average trace using instead of the mean intensity, the intensity value of
% the lower x% percentile of the intenstiy distribution in each frame,
% i.e., the baseline intensity of each frame. This is particuarly useful
% when you have a lot of drift. This trace can later be used when playing
% back the recording to substract this level to each frame. Giving you a
% much cleaner movie.
%
%   Class containing the possible paramters for preprocessing an experiment
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also preprocessExperiment, baseOptions, optionsWindow

  properties
    % Fast preprocess, only use 1 out of each 10 frames (true/false)
    fast@logical = false;

    % Only analyzes the frames between initial and final (in seconds), e.g., [0 600] for the first 600 seconds. Set as [] or [0 inf] to process everything (2D vector of positive doubles)
    subset = [0 inf];

    % Options for background image correction. If active, it will substract (or add) the selected background image to every frame, ALWAYS. This will affect every call to the original movie. e.g., viewing videos, extracting traces, ...
    % active:
    % If true, will apply background image correction
    % file:
    % image file to use for background correction
    % mode:
    % How to perform the correction
    % - substract: will substract the image to every frame
    % - add: will add the image to every frame
    backgroundImageCorrection = struct('active', false, 'file', java.io.File([pwd 'background.tif']), 'mode', {{'substract', 'add', 'multiply', 'divide'}});
    
    % Choose what movie to use in preprocessing
    % - standard: the original recording
    % - denoised: the recording produced after the denoising operation
    movieToPreprocess = {'standard', 'denoised'};    
    
    % Show the resulting average image (true/false)
    showAverageImage@logical = true;

    % Show the resulting average trace (true/false)
    showAverageTrace@logical = true;

    % Export the resulting average image (true/false)
    exportAverageImage@logical = true;

    % Export the resulting average trace (true/false)
    exportAverageTrace@logical = true;

    % File format to use when exporting images
    exportImageFormat = {'tif', 'pdf', 'eps', 'png'};

    % File format to use when exporting figures
    exportFigureFormat = {'tif', 'pdf', 'eps', 'png'};

    % Uses a median filter to try to remove noise (background) from each frame (quite slow) (true/false)
    medianFilter@logical = false;

    % The area to average each pixel for the median filter (see medianFilter) (positive integer)
    medianFilterSize = 13;

    % To also generate an average image from the low intensity pixels
    computeLowerPercentileTrace@logical = false;
    
    % Percentile where to cut the distribution for the low average image (0 to 100)
    lowerPercentile = 1;

    % To also generate an average image from the high intensity pixels
    computeHigherPercentileTrace@logical = false;

    % Percentile where to cut the distribution for the high average image (0 to 100)
    higherPercentile = 95;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.subset = [0 ceil(experiment.totalTime)];
          obj.backgroundImageCorrection.file = java.io.File([experiment.folder 'background.tif']);
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder');
        obj.backgroundImageCorrection.file = java.io.File([exp.folder 'background.tif']);
      end
    end
  end
end
