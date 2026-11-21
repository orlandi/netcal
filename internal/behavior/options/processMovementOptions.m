classdef processMovementOptions < baseOptions & plotBaseOptions
% PROCESSMOVEMENTOPTIONS Smooth traces options
%   Class containing the possible ways in which to smooth the traces
%
%   Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
%   See also smoothTraces, baseOptions, optionsWindow

  properties
    %If not empty, only analyzes the frames between initial and final (in seconds)
    subset = [0 1200];
    
    % Type of z-score to apply to the data (robust for median centered)
    zscore = {'robust', 'normal', 'none'};
    
    % Size (in sec) of the median filter. Set to 0 if you don't want to
    % apply the median filter
    filterWindow (1,1) {mustBeReal, mustBeNonnegative} = 30

    % Type of threshold (only for the schmitt trigger):
    % - relative: thresholds are defined as mean + X times the standard deviation of the signal
    % - absolute: in absolute units (this usually means dF/F)
    schmittThresholdType = {'absolute', 'relative'};
    
    % Schmitt thresholds (first the upper and then the lower). The way the schmitt trigger works is that the beginning of a burst is defined whenever the signal goes above the upper threshold, and it finishes whenever it goes below the second threshold). Set them equal for a normal threshold
    schmittThresholds (1,2) {mustBeNumeric} = [0.25, 0.25];
  end
end
