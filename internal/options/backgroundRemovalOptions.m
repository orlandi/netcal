classdef backgroundRemovalOptions < baseOptions
% BACKGROUNDREMOVALOPTIONS Options for Background Removal
%   Class containing the possible options for background removal.
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewROI, baseOptions, optionsWindow

  properties
    % Typical cell size (in pixels, only applicable to background removing)
    characteristicCelSize = 13;
    
    % This set of lower and upper threhsolds (between 0 and 1) will be used to define the background levels
    saturationThresholds = [0.2 0.3];
  end
end
