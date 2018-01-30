classdef plotBaseOptions < baseOptions
% PLOTBASEOPTIONS Base options for plotting figures
%   Class containing the base options for plotting fiugres
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    
    % Rotation of the x axis labels (0 horizontal, 90 vertical)
    XTickLabelRotation = 0;
    
    % Rotation of the y axis labels (0 horizontal, 90 vertical)
    YTickLabelRotation = 0;
    
    % Colormap to use for the plot
    colormap = 'gray';
    
    % If true, will invert the colormap scale
    invertColormap = false;
    
    % Show colorbar (true/false), only for images
    showColorbar = true;
    
    % Automatically adjust image contrast (only for images)
    rescaleImage = true;
    
    % Automatically save any generated figures
    saveFigure = false;

    % Tag to append to the name of the saved figure
    saveFigureTag = '';
    
    % Save figure type
    saveFigureType = {'pdf', 'tiff', 'png', 'jpg', 'eps'};

    % Where to save the output files (relative to the experiment or the project folders). Only valid in the experiment pipeline
    saveBaseFolder = {'experiment', 'project'};
    
    % Save figure resolution dpi (only for bitmaps)
    saveFigureResolution = 300;
    
    % Figure output quality (1 to 100), only for bitmaps, 100 for lossless compression, when possible
    saveFigureQuality = 100;
    
    % Figure size (in pixels, [width height])
    figureSize = [500 500];
    
    % Show figure (if false, it will automatically close after plotting, only useful if saveFigure is set to true)
    showFigure = true;
    
    % If true will try and tile any open figures after each iteration
    tileFigures = false;
  end
end
