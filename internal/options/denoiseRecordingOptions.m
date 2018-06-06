classdef denoiseRecordingOptions < baseOptions
% DENOISERECORDINGOPTIONS ### Denoise recording
% PCA-based movie denoising - based on [https://dx.doi.org/10.1016%2Fj.neuron.2009.08.009](https://dx.doi.org/10.1016%2Fj.neuron.2009.08.009)
%
%   Class containing the possible paramters for denoising
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also preprocessExperiment, baseOptions, optionsWindow

  properties
    % Size of blocks to use (height x width). Has to be a divisor of the original height and width
    blockSize = [128, 128];

    % If different than 0, amount of pixels that contigous blocks will overlap
    blockOverlap = [0 0];
    
    % Number of frames to read on each block. To get good results frameBlockSize/prod(blockSize) shouldn't be too small. Keep it above 0.05. The bigger the better.
    frameBlockSize = 5000;
    
    % If bigger than 1, will average blocks of frames before computing the
    % components. Keep in mind that this will effectively reduce the fps.
    % Only valid for the original movie
    frameBlockAverageSize = 1;
    
    % Will multiply the number of principal components to keep by this factor. So if the multiplier is 1.5, and it considered 10 PCs to be the optimal number, it will take 15 instead
    maximumPCsMultiplier = 1;
    
    % True to process each frame in small blocks (might be a speed up in some cases, usually not recomended)
    readSmallBlocks@logical = false;
    
    % Movie to use for the recording
    movie = {'original', 'glia'};
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        if(experiment.width == 960 && experiment.height == 720)
          obj.blockSize = [192 144];
        end
        try
          obj.frameBlockSize = min(5000, experiment.numFrames);
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
