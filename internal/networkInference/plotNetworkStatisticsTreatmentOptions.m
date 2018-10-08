classdef plotNetworkStatisticsTreatmentOptions < plotStatisticsTreatmentOptions & baseOptions
% PLOTNETWORKSTATISTICSTREATMENTOPTIONS # Options for plotting network statistics
% Plots statistics associated to network structure
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotNetworkStatisticsTreatment, plotStatisticsTreatmentOptions, baseOptions, optionsWindow

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
      obj.comparisonType = {'difference', 'ratio', 'differencePreZero', 'differenceIntersect', 'ratioIntersect', 'decreaseIntersect', 'increaseIntersect', 'Mann-Whitney','Kolmogorov-Smirnov', 'Ttest2'};
      scoreList = computeNetworkStatistic([], 'list');
      obj.statistic = [scoreList' 'all' 'ask'];
%       obj.statistic = {'degree', 'output degree', 'input degree', 'total num connections', ...
%                        'clustering coefficient', 'cc feedback', 'cc feedforward', 'cc middleman', 'cc in', 'cc out', ...
%                        'transitivity', ...
%                        'assortativity in-out', 'assortativity out-in', 'assortativity out-out', 'assortativity in-in', 'global efficiency', ...
%                        'local efficiency', 'rich club coeff', 'coreness', ...
%                        'char path length', 'radius', 'diameter', 'eccentricity', ...
%                        'louvain num communities', 'louvain avg community size', 'louvain largest community', 'louvain community statistic', ...
%                        'modularity num communities', 'modularity avg community size', 'modularity largest community', 'modularity statistic', ...
%                        'num connected comp', 'largest connected comp', 'avg comp size', 'correlation num clusters', 'correlation avg cluster size', 'correlation largest cluster', ...
%                        'eigenvector centrality', 'pagerank centrality', 'betwenness centrality', 'louvain intercommunity degree', 'louvain intercommunity inout assortativity', ...
%                        'louvain provincial hubs', 'louvain connector hubs', 'num hubs', 'small world index', 'ask', ''};
      obj = setExperimentDefaults@plotStatisticsTreatmentOptions(obj, experiment);
    end
  end
end
