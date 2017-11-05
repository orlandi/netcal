classdef plotAverageImageOptions < baseOptions & plotBaseOptions
% PLOTAVERAGEIMAGEOPTIONS options for plotting the average image
%   Class containing the parameters for avalanche analysis
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotAverageImage, plotBaseOptions, baseOptions, optionsWindow

  properties
    % To plot the ROI image as an overlay:
    % - none: doesn't show any ROI
    % - fast: plots the ROI fast (merges boundaries)
    % - edge: only shows the ROIs perimeter (empty inside)
    % - full: plots the ROI accurately (recognizes boundaries)
    showROI = {'none', 'fast', 'edge', 'full'};
    
    % Transparency for the ROI image overlay (0 fully transparent, 1 opaque)
    ROItransparency = 0.5;
  end
  methods
    function t = plotAverageImageOptions(varargin)
      t@baseOptions(varargin{:});
      t@plotBaseOptions(varargin{:});
    end
  end
end
