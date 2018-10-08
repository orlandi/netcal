classdef spikeFeaturesDistributionPlotOptions < baseOptions
% SPIKEFEATURESDISTRIBUTIONPLOTOPTIONS Spike features distribution plot options
%   Class containing the options
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also preprocessExperiment, baseOptions, optionsWindow

  properties
      % Type of estimate of the underlying data distribution
      % - 'unbounded kernel density' - normal kernel density estimation with unbounded support (see ksdensity)
      % - 'unbounded kernel density' - normal kernel density estimation with positive support, use that when the density cannot extend to negative values (see ksdensity)
      % - 'histogram' - standard histogram with automatic bin size (see sshist)
      % - 'custom integer' - histogram with custom number of bins
      distributionType = {'unbounded kernel density','positive kernel density', 'histogram', ''};
      
      % Colormap to use for the lines/bins - one for each cluster
      colormap = 'parula';
  end
end