classdef cleanROIfromCellSortOptions < baseOptions
% CLEANROIFROMCELLSORTOPTIONS Options for ROI cleaning from CellSort procedure
%   Class containing the possible options for cleaning CellSort ROIs
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also cleanROIfromCellSort, baseOptions, optionsWindow

  properties
    % Minimum overlap between ROI to merge them together (for the first fast stage)
    overlappingThreshold = 0.7;
    
    % Minimum correlation to merge traces together (for the second accurate stage)
    correlationThreshold = 0.85;

    % If fast, will only pick one out of every 10 frames on the traces to
    % meaasure correlations
    fast = false;
    
    % Allowed separation between ROI to try and merge based on correlation
    pixelLeeway = 5; %

    % Only merge ROI if they form a single connected component
    forceOverlap = false;

    % 2 element vector. If not empty, will only extract traces between those 2 times (in seconds) for the correlation analysis
    subset = [];
  end
end
