classdef fluorescenceAutomaticOptions < baseOptions
% FLUORESCENCEAUTOMATICOPTIONS Options for Automatic fluorescence
%   Class containing the possible options for automatic fluorescence analysis
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % Perform preprocessing
    preprocessing@logical = true;

    % ROI selection mode
    ROIselection = {'automatic', 'external file', 'none'}
    
    % Extract traces
    extractTraces@logical = true;
    
    % Smooth traces
    smoothTraces@logical = true;
    
    % Similarity measures
    similarity@logical = true;
  end
end
