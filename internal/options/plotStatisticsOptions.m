classdef plotStatisticsOptions < plotFigureOptions & baseOptions
% PLOTSTATISTICSOPTIONS # Main class to plot statistics
%   Produces a distribution estimation or boxplot for a given spike statistic
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotStatistics, plotFigureOptions, baseOptions, optionsWindow

  properties
    % Chosen statistic to plot
    statistic = {'Main statistic', ''};
    
    % How to run this function on the pipeline:
    % - experiment: will run separately on each checked experiments (usually results in single experiment statistics or distributions)
    % - project: will run simultaneously on all checked experiments (usually results on averages across experiments)
    pipelineMode = {'experiment', 'project'};
    
    % Group to perform function on:
    % - none: will NOT use groups, i.e., use all elements
    % - ask: will show a popup window where the user can select the interested groups (useful for discontinous selection). You have to write 'ask' yourself, it will not show up within the options
    % - all: will use all defined groups
    % - group parent: will uuse all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % How to estimate distributions (only if pipelineMode = experiment or plotType = distribution on pipelineMode = project)
    % mode:
    % How to plot the underlying distribution (only for experiment pipeline):
    % - unbounded: unbounded kernel density
    % - postive: positive kernel density
    % - histogram: normalized histogram as a barplot
    % - raw: histogram without normalization as a barplot
    % - histogram line: normalized histogram as a line
    % - raw line: histogram without normalization as a line
    % distributionBins:
    %  Bins to use for the distribution plot (if set to histogram or raw):
    % - 0 or empty: Automatic estimation
    % - Integer: number of bins
    % - Text: will be evaluated as is to define a bin list:, e.g., "linspace(0, 20, 100)", "0:0.1:10", ... (without the quotation marks)
    % additionalOptions:
    % - Additonal options to pass to the distribution estimation call (will be passed directly to the distribution). Usually comma separated pairs of values, see ksdensity and hist help functions for details.
    distributionEstimation = struct('mode', {{'unbounded', 'positive', 'histogram', 'raw', 'histogram line', 'raw line'}}, ...
                                'distributionBins', '0', 'additionalOptions', '');

    % Options for pipelineProject = project
    % plotType:
    % How to plot the data:
    % - boxplot: using a boxplot (duh)
    % - distribution: will plot all the distributions (see distributionEstimation)
    % groupingOrder:
    % How to group multiple experiments:
    % - none: does not group them
    % - label average: will merge experiments with the same label and produce a single plot
    % labelGroups:
    % Labels to use if any groupingOrder is set (only for pipelineMode project). Enter here the sets of labels that define each group (comma separated), each row one group. If empty it will use all available labels
    % barGroupingOrder:
    % How to group the bars together
    % - default: each experiment (if groupingOrder = none) or label (if groupingOrder = label average) will become a block in the x axis. Each group will have a different color
    % - group: each group will become a block in the x axis. Each experiment/label will have a different color
    % factor:
    % How to define the samples:
    % - experiment: each experiment is a sample (averaged over each element)
    % - event: each event (ROI in single cell statistics) or element (for global measures like bursts) from an experiment is a sample (means pooling all data from a set of experiments together)
    % - mixed: will compare the distributions of each experiment independently. At the end it will compute an average p-value across all comparisons
    % factorAverageFunction:
    % How to perform the averages (or other statistic) between samples (only if factor = experiment):
    % - mean: use the mean
    % - median: use the median
    % - std: use the standard deviation
    % - skewness: use the skewness
    % - cv: coefficient of variation
    % showSignificance:
    % If any significance (***) should be ploted:
    % - none: no significance is shown
    % - partial: only those below 0.05 will be shown
    % - all: all checks will be shown
    % significanceTest:
    % Type of statistical test to use
    % - Mann-Whitney: uses two-tailed Mann-Whitney test
    % - Kolmogorov-Smirnov: uses two-tailed kolmogorov-Smirnov test
    % avoidCrossComparisons:
    % If true, will not compute significance between groups that do not share labels
    % computeIntraGroupComparisons:
    % (Only for mixed factor) If true, will also compute significance across samples from the same group
    % HolmBonferroniCorrection:
    % If true, will apply Holm-Bonferroni connection to any significance checks
    pipelineProject = struct('plotType', {{'boxplot', 'distribution'}}, 'groupingOrder', {{'none', 'label average'}}, 'labelGroups', {{'';''}}, 'barGroupingOrder', {{'default', 'group'}}, 'factor', {{'experiment', 'event', 'mixed'}}, 'factorAverageFunction', {{'mean', 'median', 'std', 'var', 'skewness', 'cv'}}, 'showSignificance', {{'none', 'partial', 'all'}}, 'significanceTest', {{'Mann-Whitney','Kolmogorov-Smirnov'}}, 'avoidCrossComparisons', true, 'computeIntraGroupComparisons', false, 'HolmBonferroniCorrection', false);
    
    % If true will turn any zero values into NaNs (so they are not used for the statistics. Useful when working with rates and things like that
    zeroToNan = true;
  end
  
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.group = getExperimentGroupsNamesFull(experiment);
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames');
        groups = getExperimentGroupsNamesFull(exp);
        
        if(~isempty(groups))
          obj.group = groups;
          obj.group{end+1} = '';
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
      end
    end
    function obj = setProjectDefaults(obj, project)
    end
  end
end
