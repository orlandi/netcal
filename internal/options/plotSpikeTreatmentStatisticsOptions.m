classdef plotSpikeTreatmentStatisticsOptions < plotBaseOptions & baseOptions
% PLOTSPIKETREATMENTSTATISTICSOPTIONS # Plot Spike Statistics betewen experiments
%   Produces a boxplot for a given spike statistic, e.g., ISI, IBI, ...
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotSpikeStatistics, plotBaseOptions, baseOptions, optionsWindow

  properties
    % Chosen statistic to plot
    statistic = {'Num of spikes', ''};

    % In what order should the experiments be grouped
    % - paired: consecutive groups belong to different treatments (basal, treated, basal, treated)
    % - sequential: consecutive groups belong to the same treatment (basal, basal, ..., treated, treated, ...)
    experimentGroupOrder = {'paired', 'sequential'};
    
    % Number of treatments present
    numberTreatments = 2;
    
    % If it should also compare differences between the first and last treatments (only valid when more than 2 treatments are present)
    compareExtremes = false;
    
    % Group to perform function on:
    % - none: will use all elements
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % How to group multiple experiments
    % - none: does not group them
    % - label: will group experiments with the same label and produce a single plot
    % - label average: will merge experiments with the same label and produce a single plot
    groupingOrder = {'none', 'label', 'label average'};
    
    % If groupingOrder is set to label, enter here the sets of labels that define each group (comma separated), each row one group. If empty it will use all available labels. NOT WORKING YET
    labelGroups = cell(2,1);
    
    % How to define the samples
    % - experiment: each experiment is a sample (averaged over each element)
    % - ROI: each ROI from an experiment is a sample (means pooling all data from a set of experiments together)
    factor = {'experiment', 'ROI'};
    
    % If true will turn any zero values into NaNs (so they are not used for the statistics. Useful when working with rates and things like that
    zeroToNan = false;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.colormap = 'lines';
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.group = getExperimentGroupsNamesFull(experiment);
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
        try
          obj.statistic = experiment.spikeFeaturesNames;
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames', 'spikeFeaturesNames');
        groups = getExperimentGroupsNamesFull(exp);
        if(~isempty(groups))
          obj.group = groups;
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
        if(isfield(exp, 'spikeFeaturesNames'))
          obj.statistic = exp.spikeFeaturesNames(:)';
          obj.statistic{end+1} = '';
        else
          obj.statistic = '';
        end
        
      end
    end
    function obj = setProjectDefaults(obj, project)
      obj.colormap = 'lines';
    end
  end
end
