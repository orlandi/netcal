classdef ROIselectionOptions < baseOptions
% ROISELECTIONOPTIONS Options for ROI selection
%   Class containing the possible options for the ROI selection procedures, both automatic and manual
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewROI, baseOptions, optionsWindow

  properties
    % Desired size of manually defined ROIs (side for square, diameter for circles in pixels)
    sizeManual = 16;

    % Desired size for the active contour procedure (side in pixels, use an even number)
    sizeActiveContour = 4;
    
    % Typical cell size (in pixels, only applicable to background removing)
    sizeAutomaticCellSize = 13;
  end
end
