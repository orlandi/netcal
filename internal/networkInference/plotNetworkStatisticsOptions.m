classdef plotNetworkStatisticsOptions < plotStatisticsOptions & baseOptions
% PLOTNETWORKSTATISTICSOPTIONS # Options for plotting network statistics
% Plots statistics associated to network structure
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotNetworkStatistics, plotStatisticsOptions, baseOptions, optionsWindow

  properties
    % What nemtwork inference measure to use:
    % GTE: Generalized Transfer Entroy
    inferenceMeasure = {'GTE', 'GTE unconditioned', 'xcorr'};
    
    % Confidence level measure to establish significance
    confidenceLevelThreshold = 2;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'degree', 'output degree', 'input degree', 'clustering coefficient', 'transitivity', ...
                       'assortativity in-out', 'assortativity out-in', 'assortativity out-out', 'assortativity in-in', 'global efficiency', ...
                       'local efficiency', 'rich club coeff', 'coreness', ...
                       'char path length', 'radius', 'diameter', 'eccentricity', ...
                       'louvain num communities', 'louvain avg community size', 'louvain largest community', 'louvain community statistic', ...
                       'modularity num communities', 'modularity avg community size', 'modularity largest community', 'modularity statistic', ...
                       'num connected comp', 'largest connected comp', 'avg comp size', 'ask', ''};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
