classdef ROIautomaticOptions < baseOptions
% ROISELECTIONOPTIONS Options for ROI selection
%   Class containing the possible options for the ROI selection procedures, both automatic and manual
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewROI, baseOptions, optionsWindow

  properties
    % Prefered automatic ROI detection method
    automaticType = {'threshold', 'quick_dev', 'splitThreshold'};

    % Typical cell size (in pixels, only applicable to quick_dev and splitThreshold). The actual instruction is  to delete any objects with less pixels than max(9, (sizeAutomaticCellSize/2-1)^2);
    sizeAutomaticCellSize = 13;

    % Threshold to use (between 0 and 1, only applicable to automatic threshold)
    sizeAutomaticThreshold = 0.1;
    
    % Filter type (to remove noise in the signal, only for quick_dev)
    filterType = {'gaussian', 'median', 'none'};
    
    % To try to remove background noise before detecting ROI (this is the
    % same as pressing the remove background button on the view ROI screen,
    % so if you pressed it there, don't do it here)
    removeBackgroundFirst = false;
    
    % Remove dead pixels (if your camera has them)
    removeDeadPixels = true;
    
    % Dead pixel multiplier (mean+multiplier*std of the signal is considered a dead pixel)
    deadPixelMultiplier = 10;
  end
end
