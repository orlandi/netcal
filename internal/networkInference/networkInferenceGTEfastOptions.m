classdef networkInferenceGTEfastOptions < plotFigureOptions & baseOptions
% GTEOPTIONS Options for Generalized Transfer Entropy
%   Class containing the parameters to perform network inference with the GTE algorithm
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also networkInferenceGTEfast, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Temporal binning to create the time series (in s)
    binSize = 0.1;
    
    % If the instant feedback term should be used
    instantFeedbackTerm = true;
    
    % Markov Order of the time series [I J] for I->J
    markovOrder = [2 2];

    % If conditioning should be applied
    applyConditioning = true;
    
    % Threshold to use for the conditioning level
    conditioningThreshold = 0.1;
    
    % If true, will plot the global fluorescence distribution (with the conditioning threshold)
    plotGlobalFluorescence = true;
    
    % What distribution to use to establish significance:
    % prepost: joint distribution of pre (inputs) and post (outputs) scores for each link
    % pre: distribution of pre (input) scores
    % global: all scores
    significanceDistribution = {'prepost', 'pre', 'global'};
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.group = getExperimentGroupsNamesFull(experiment);
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
        if(isfield(experiment, 'fps'))
          obj.binSize = 1/experiment.fps;
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames', 'fps');
        groups = getExperimentGroupsNamesFull(exp);
        if(~isempty(groups))
          obj.group = groups;
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
        if(isfield(exp, 'fps'))
          obj.binSize = 1/exp.fps;
        end
      end
    end
  end

end
