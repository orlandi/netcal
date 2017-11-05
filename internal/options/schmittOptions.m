classdef schmittOptions < baseOptions
% SCHMITTGOPTIONS Schmitt trigger options
%   Class containing the parameters to perform spike inference with a
%   schmitt trigger. It will identify a spike whenever the signal goes
%   above the upperThreshold and doesn't go below the lower threshold. It
%   will associate the spike with the average time between the rise and the
%   local maxima, and also store the duration and ampltiude in separated
%   variables.
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also Peeling, baseOptions, optionsWindow

  properties
    % First threshold for spike detection (signal has to go above this
    % value, see also threshold type)
    upperThreshold = 3;

    % Second threshold for spike detection (signal has to go below this
    % value, see also threshold type)
    lowerThreshold = 0.9;
    
    % ROI index used to check inference results with a single trace (only used in training mode)
    trainingROI = 1;
    
    % Type of threshold measure. Relative, means it will look for
    % multipliers of the standard deviation of the signal (above the mean).
    % Absolute will look for values directly above whatever the threshold
    % is.
    thresholdType = {'relative', 'absolute'};
  end
end
