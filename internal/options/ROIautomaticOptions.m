classdef ROIautomaticOptions < baseOptions
% ROISELECTIONOPTIONS Options for ROI selection
%   Class containing the possible options for the ROI selection procedures, both automatic and manual
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also viewROI, baseOptions, optionsWindow

  properties
    % Prefered automatic ROI detection method
    automaticType = {'threshold', 'quick_dev', 'splitThreshold', 'thresholdSmall'};

    % Typical cell size (in pixels, only applicable to quick_dev and splitThreshold). The actual instruction is  to delete any objects with less pixels than max(9, (sizeAutomaticCellSize/2-1)^2);
    sizeAutomaticCellSize = 13;

    % Threshold to use (between 0 and 1, only applicable to thresohld and splitThreshold)
    sizeAutomaticThreshold = 0.1;
    
    % Filter type (to remove noise in the signal, only for quick_dev)
    filterType = {'gaussian', 'median', 'none'};
    
    % To try to remove background noise before detecting ROI (this is the
    % same as pressing the remove background button on the view ROI screen,
    % so if you pressed it there, don't do it here)
    % active:
    % If the opration will be performed or not
    % characteristicCellSize:
    % Typical cell size (in pixels, only applicable to background removing)
    % saturationThresholds:
    % This set of lower and upper threhsolds (between 0 and 1) will be used to define the background levels
    backgroundRemoval = struct('active', false, 'characteristicCellSize', 13, 'saturationThresholds', [0.2 0.3]);
    
    % To try and remove dead pixels first from the image (those that are much brigther than the rest of the image
    % active:
    % If the opration will be performed or not
    % deadPixelMultiplier:
    % Any pixel with fluorescence above mean+multiplier*std of all the image values is considered a dead pixel
    deadPixelRemoval = struct('active', false, 'deadPixelMultiplier', 10);
  end
end
