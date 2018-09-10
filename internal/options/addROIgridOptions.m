classdef addROIgridOptions < baseOptions
% ADDROIGRIDOPTIONS # Add ROI Grid
%   Options for adding a grid of ROIs
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also viewROI, baseOptions, optionsWindow

  properties
    % Type of grid to generate:
    % - 2 point circle: will create a grid around a circle (defined by its center and radius)
    % - 3 point circle: will create a grid around a circle (defined by three points on its perimeter)
    % - Rectangle (subregion): will create a grid around a rectangle (defined by two of its corners)
    % - Rectangle (whole image): will create a grid around a rectangle that occupies the whole image
    gridType = {'2 point circle', '3 point circle', 'rectangle (subregion)', 'rectangle (whole image)'};
    
    % Number of rows on the grid
    rows = 8;
    
    % Number of columns on the grid
    cols = 8;
    
    % If true, will delete small ROIs left by the circular grids (those around the perimeter)
    deleteSmallROI = true;
    
    % If true, will first delete any existing ROI
    resetROI = true;
  end
  methods 
    
  end
end
