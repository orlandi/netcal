classdef defaultFPSoptions < baseOptions
% DEFAULTFPSOPTIONS # Default Framerate options
%   Sets and controls the framerate of recordings that do not have it on their metadata
%
%   Copyright (C) 2016-2018, Javier G. Orlandi
%
%   See also netcal, baseOptions, optionsWindow

  properties
    % Framerate of the recording (in frames per second)
    frameRate = 20;

    % If true, will always use this framerate for all new recordings.
    useAsDefault = false;
  end
end
