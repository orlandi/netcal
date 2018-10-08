classdef preprocessExperimentPercentileOptions < baseOptions
% PREPROCESSEXPERIMENTPERCENTILEOPTIONS ### Preprocess experiment percentile
% Returns an image whose pixel intensities are the values of a given percentile across time.
% Set a larger value, e.g., 95 to try to maximize the chanes of detecting
% firing events. Uses reservoir sampling for the computation.
%
%   Class containing the possible paramters for computing the perenctile image of an experiment
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also preprocessExperiment, baseOptions, optionsWindow

  properties
    % Show the resulting image (true/false)
    showImage@logical = true;

    % Export the resulting image (true/false)
    exportImage@logical = true;

    % File format to use when exporting images
    exportImageFormat = {'tif', 'pdf', 'eps', 'png'};

    % Only analyzes the frames between initial and final (in seconds), e.g., [0 600] for the first 600 seconds. Set as [] or [0 inf] to process everything (2D vector of positive doubles)
    subset = [0 600];

    % Maximum number of GB to use to store the percentiles
    maxMemoryUsage = 2;

    % Fraction of the frames to use to compute the percentile (between 0 and 1)
    fracionFramesUsed = 0.2;
    
    % Percentile to use to compute the new image
    percentile = 95;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.subset = [0 round(experiment.totalTime)];
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
