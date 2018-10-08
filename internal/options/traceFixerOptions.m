classdef traceFixerOptions < baseOptions
% Optional input parameters for traceFixer
%
% See also traceFixer
  properties
    % Threshold to detect events (times the std deviation above the mean)
    threshold = 5;

    % Minimum length of an event (in seconds)
    thresholdType = {'relative', 'absolute'};

    % Automatic detection method to use:
    % - sign: based on overal sign change across traces
    % - TVD: total variation denoising
    detectionMethod = {'sign', 'TVD'};
    
    % Event sampling size (in seconds, the region where it will try to find something and compute statistics).
    % Here you might want to use a small sampling size for neurons or high frequency signals. For glia you might want to use a longer one
    expansionInterval = [-3, 3];
  end
end
