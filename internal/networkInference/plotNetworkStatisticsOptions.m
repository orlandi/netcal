classdef plotNetworkStatisticsOptions < plotStatisticsOptions & baseOptions
% PLOTNETWORKSTATISTICSOPTIONS # Options for plotting network statistics
% Plots statistics associated to network structure
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotNetworkStatistics, plotStatisticsOptions, baseOptions, optionsWindow

  properties
    % If true will divide the measured statistic from the number of cells in the current group. Only applies to measures
    % that deal with average or largest sizes, i.e., X avg community size, X largest community, etc
    normalizeGlobalStatistic = false;
    
    % Number of surrogates to use (for measures involving null models)
    numberSurrogates = 20;
    
    % Any networks with less than this number of nodes will be skipped
    minimumSize = 0;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'degree', 'output degree', 'input degree', 'total num connections', ...
                       'clustering coefficient', 'cc feedback', 'cc feedforward', 'cc middleman', 'cc in', 'cc out', ...
                       'total feedforward triangles', 'total feedback triangles', 'transitivity', ...
                       'assortativity in-out', 'assortativity out-in', 'assortativity out-out', 'assortativity in-in', 'global efficiency', ...
                       'local efficiency', 'rich club max coeff', 'rich club top20 coeff', 'rich club coeff corrected', 'coreness', ...
                       'char path length', 'radius', 'diameter', 'eccentricity', ...
                       'louvain num communities', 'louvain avg community size', 'louvain largest community', 'louvain community statistic', ...
                       'modularity num communities', 'modularity avg community size', 'modularity largest community', 'modularity statistic', ...
                       'num connected comp', 'largest connected comp', 'avg comp size', 'correlation num clusters', 'correlation avg cluster size', 'correlation largest cluster', ...
                       'eigenvector centrality', 'pagerank centrality', 'betwenness centrality', 'louvain intercommunity degree', 'louvain intercommunity inout assortativity', ...
                       'louvain provincial hubs', 'louvain connector hubs', 'num hubs', 'small world index', 'avg connection length', 'ask', ''};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
