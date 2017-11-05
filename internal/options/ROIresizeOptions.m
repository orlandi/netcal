classdef ROIresizeOptions < baseOptions
% ROIRESIZEOPTIONS Options for resizing ROI
%   All ROI shapes will be transformed to the desired shape and resized to the desired size from their current center of mass
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewROI, baseOptions, optionsWindow

  properties
    % Desired size for the ROI (in pixels). Please use an odd value
    % - square: size corresponds to the side of the square
    % - circle: size corresponds to the diameter of the circle
    size = 7;

    % Shape to match when resizing the ROI
    shape = {'square', 'circle'};
  end
end
