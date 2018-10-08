classdef plotQCECOptions < plotBaseOptions & baseOptions
% PLOTQCECOPTIONS Base options for plotting q-CE curves
%   Class containing the options for plotting q-CE curves
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also plotQCEC, plotBaseOptions, baseOptions, optionsWindow

  properties
    % How to run this function on the pipeline:
    % - experiment: will run separately  on every checked experiment (usually results in single experiment statistics or distributions)
    % - project: will run simultaneously on all checked experiment (usually results on averages across experiments)
    pipelineMode = {'experiment', 'project'};
    
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Type of plot:
    % - full: qCEC curve for every singlet races
    % - mean: mean qCEC curve wiht its RMSE
    type = {'full', 'mean'};
    
    % How to sort the plots (only valid when plotting multiple experiments)
    % - original: as they come
    % - label: will group experiments with the same label together
    sortingOrder = {'original', 'label'};
    
    % How to group multiple experiments (only valid when plotting multiple experiments)
    % - none: does not group them
    % - label: will merge experiments with the same label and produce a single curve
    groupingOrder = {'none', 'label'};
    
    % If true, will also plot the standard (permutation) entropy, i.e.,  q=1
    plotStandardEntropy@logical = true;
    
    % If true, will also plot the standard (permutation) complexity, i.e.,  q=1
    plotStandardComplexity@logical = true;
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
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames');
        groups = getExperimentGroupsNamesFull(exp);
        if(~isempty(groups))
          obj.group = groups;
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
      end
    end
    function obj = setProjectDefaults(obj, project)
      obj.colormap = 'lines';
    end
  end
end
