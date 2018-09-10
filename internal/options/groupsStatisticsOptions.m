classdef groupsStatisticsOptions < baseOptions
% GROUPSSTATISTICSOPTIONS Options for the group statistics
%   Class containing the options for computing and displaying group statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also viewGroups, baseOptions, optionsWindow

  properties
    % Distribution plot type (boxplot, violin, notboxplot, univarscatter)
    distributionType = {'boxplot', 'violin', 'notboxplot', 'univarscatter'};

    % Type of nearest neighbor measure:
    % - 'absolute' - returns the value of the distance (in pixels)
    % - 'relative' - returns the difference to the distance of a randomly distributed sample (the null model)
    nearestNeighborMeasure = {'absolute', 'relative'}

    % What to show above the bars (related to the statistical testing, in that case the null hypothesis is that the spatial distribution of the groups is homogeneous TBC)
    % - 'stars' - stars associated to the significance level (* 0.05, ** 0.01, *** 0.001, **** 0.0001)
    % - 'pvalue' - pvalue at which the null hypothesis is rejected
    showAboveBars = {'stars', 'pvalue', 'none'}

    % Degrees of rotation for the x labels (0 horizontal, 90 vertical)
    xLabelsRotation = 0;

    % Main colormap
     colormap = 'parula';
  end
end