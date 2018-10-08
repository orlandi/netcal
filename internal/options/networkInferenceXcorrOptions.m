classdef networkInferenceXcorrOptions < networkInferenceOptions
% NETWORKINFERENCEXCORROPTIONS # Cross-correlation based network inference
%   Uses cross-correlation as a proxy of functional connectivity, using either the maximum value (for any delay) or the 0 lag measure
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also networkInferenceOptions, baseOptions, optionsWindow

  properties
    % Value of the cross-correlation to use:
    % - max: the maximum across all delays (symmetric measure)
    % - maxPositive: the maximum across all positive delays (asymetric measure)
    % - 0lag: the maximum at 0-lag
    value = {'max', 'maxPositive', '0lag'};
    
    % maximum lag to look at when computing the cross-corrleation (in seconds). If emptym, it will use all
    maximumLag = 5;
    
    % How to normalize the cross-correlation measure (see MATLAB's xcorr)
    % - coeff: normalizes the sequence so that the auto-correlations at zero lag are identically 1.0
    % - none: no scaling
    normalizationType = {'coeff', 'none'};
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj = setExperimentDefaults@networkInferenceOptions(obj, experiment);
    end
  end
end
