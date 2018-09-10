classdef avalanchePlotsOptions < baseOptions
% AVALANCHEPLOTSOPTIONS options for avalanche plots
%   Class containing the parameters for avalanche plots
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also avalancheOptions, baseOptions, optionsWindow

  properties
    % Number of bins to use when plotting the pdf or binned cdfs
    plotBins = 100;
    
    % Type of distribution to plot
    distributionPlotType = {'pdf', 'cdf staircase', 'cdf dotted'};
    
    % plotType, to define if we plot the distributions in a single window or together
    plotType = {'together', 'single'};
    
    % Marker for the plots
    plotMarker = {'.', 'o', '*', 'x', 's'};
  end
end
