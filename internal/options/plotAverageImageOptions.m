classdef plotAverageImageOptions < plotFigureOptions & baseOptions
% PLOTAVERAGEIMAGEOPTIONS options for plotting the average image
%   Class containing the parameters for avalanche analysis
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotAverageImage, plotFigureOptions, baseOptions, optionsWindow

  properties
    % To plot the ROI image as an overlay:
    % - none: doesn't show any ROI
    % - fast: plots the ROI fast (merges boundaries)
    % - edge: only shows the ROIs perimeter (empty inside)
    % - full: plots the ROI accurately (recognizes boundaries)
    showROI = {'none', 'fast', 'edge', 'full'};
    
    % Transparency for the ROI image overlay (0 fully transparent, 1 opaque)
    ROItransparency = 0.5;
    
    % Automatically adjust image contrast
    rescaleImage = true;
    
    % Show colorbar (true/false)
    showColorbar = true;
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      obj.styleOptions.colormap = 'gray';
      obj.saveOptions.saveFigureType = 'tiff';
    end
  end
end

