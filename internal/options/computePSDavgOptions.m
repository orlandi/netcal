classdef computePSDavgOptions < baseOptions
% COMPUTEPSDAVGOPTIONS ### Compute Power Spectrum Density AVerages
% Computes several average images based on PSD at various frequency cutoffs
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also preprocessExperiment, baseOptions, optionsWindow

  properties
    % Size of blocks to use (height x width). Has to be a divisor of the original height and width. Also note that the whole block should fit on memory, i.e., X*Y*T, where T is the total number of frames. Note that the blockSize has a huge impact on performance, since all frames have to be read once per block. Keep the blocks as large as possible
    blockSize = [128, 128];

    % 1st and last frame to consider when computing the PSD. Leave empty to use all frames
    frameRange = [1 10000];
    
    % Frequency values (in Hz) used to define frequency intervals, e.g., [0.01 0.1 1] will create 2 images. One with freqs between 0.01 and 0.1 Hz and one between 0.1 and 1 Hz. Frequencies will be cut at real max and min frequencies
    freqLimits = [0 0.01, 0.1, 1, 100];
    
    % Sampling frequency divider. Use integers. Note that the maximum frequency will be fps/samplingFreqMultiplier, but everything will go faster since it will skip frames
    samplingFreqDivider = 1;
    % Average function to use:
    % - logmexp: exponential of the mean logarithm
    % - mean
    % - median
    avgMode = {'logmexp', 'mean', 'median'};
       
    % True to process each frame in small blocks (might be a speed up in some cases, usually not recomended)
    readSmallBlocks@logical = false;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        if(experiment.width == 960 && experiment.height == 720)
          obj.blockSize = [192 144];
        end
        obj.frameRange = experiment.numFrames;
        obj.freqLimits = [0 0.01, 0.1, 1, experiment.fps/2];
      end
    end
  end
end
