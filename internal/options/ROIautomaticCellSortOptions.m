classdef ROIautomaticCellSortOptions < baseOptions
% ROISELECTIONCELLSORTOPTIONS Options for ROI selection with CellSort
%   Class containing the possible options for the CellSort ROI Selection
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewROI, baseOptions, optionsWindow

  properties
    % Size of the gaussian kernel used for smoothing (in pixels)
    gaussianSmoothingKernelSize = 4;
    
    % Threshold for the spatial filters (standard deviations)
    spatialTheshold = 3;
    
    % Minimum number of pixels in a ROI
    minimumSize = 40;
    
    % If true, eliminates any ROI found at the borders of any block. Useful if you are using overlapping blocks in denoising. Will not eliminate ROI at the edges of the FOV
    eliminateBorderROIs = false;
  end
end
