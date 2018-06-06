classdef plotFigureOptions < baseOptions
% PLOTFIGUREOPTIONS # Default options for plotting figures
%   These options will be inherited by most functions that plot something that isn't an image
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    
    % Plot style options
    % figureSize:
    % Size of the figure (in pixels) [width height]
    % figureTitle:
    % Title for the figure & window (if empty, it will use the default)
    % xLabel:
    % Name of the x axis (if empty, will use the default)
    % yLabel:
    % Name of the y axis (if empty, will use the default)
    % XTickLabelRotation:
    % Rotation of the x axis labels (0 horizontal, 90 vertical)
    % YTickLabelRotation:
    % Rotation of the Y axis labels (0 horizontal, 90 vertical)
    % colormap:
    % Main colormap to use
    % invertColormap:
    % If true, will invert the colormap scale
    % notch:
    % If true, will show the notches: The notch is centred on the median and extends to +-1.58*IQR/sqrt(N), where N is the sample size (number of non-NaN). Generally if the notches of two boxes do not overlap, this is evidence of a statistically significant difference between the medians.
    % tileFigures:
    % If true, will try to tile all opened figures at the end
    styleOptions = struct('figureSize', '[500 500]', 'figureTitle', [], 'xLabel', [], 'yLabel', [], 'XTickLabelRotation', 0, 'YTickLabelRotation', 0, 'colormap', 'lines', 'invertColormap', false, 'notch', false, 'tileFigures', false);
    
    % Save options
    % saveFigure:
    % Automatically save any generated figures
    % saveBaseFolder:
    % Default folder to save the figure (only for experiment Pipeline)
    % saveFigureTag:
    % Tag to append to the name of the saved figure
    % saveFigureType:
    % File type (pdf & eps require ghostscript installed)
    % saveFigureResolution:
    % DPI of the output figure (only for bitmaps)
    % saveFigureQuality:
    % Figure output quality (1 to 100), only for bitmaps, 100 for lossless compression, when possible
    % onlySaveFigure:
    % If true, will only save the figure. Will not be displayed on the screen (but the MATLAB renderer has to be available)
    % saveExperiment:
    % If the experiment should be saved after this function is run. If disabled, options might not be memorized, but might speed up running a batch figure generation
    saveOptions = struct('saveFigure', false, 'saveBaseFolder', {{'experiment', 'project'}}, 'saveFigureTag', '', 'saveFigureType', {{'pdf', 'tiff', 'png', 'jpg', 'eps'}}, 'saveFigureResolution', 300, 'saveFigureQuality', 100, 'onlySaveFigure', false, 'saveExperiment', true);
    
    % Script with additional figure options that will be run at the end of figure generation
    additionalFigureOptions = java.io.File('');
  end
end
