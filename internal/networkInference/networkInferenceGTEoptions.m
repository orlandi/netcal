classdef networkInferenceGTEoptions < baseOptions
% NETWORKINFERENCEGTEOPTIONS # Options class to perform GTE inference
%   Defines modes, surrogaters and such
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will NOT use groups, i.e., use all elements
    % - ask: will show a popup window where the user can select the interested groups (useful for discontinous selection). You have to write 'ask' yourself, it will not show up within the options
    % - all: will use all defined groups
    % - group parent: will use all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Use of surrogate data to generate confidence intervals and significance levels
    % enable:
    % If we should use surrogates
    % useAllAtOnce:
    % If true, will generate and process all surrogates of a single cell at once (should be faster if enough memory is available)
    % type:
    % What kind of surrogates to generate:
    % - ISIconserved: will generate new data with the same ISI statistics (resampling existing ISIs with repetition)
    % - poisson: (TODO) will generate new spikes from a possion process with the same rate (average number of spikes)
    % - spikeCountConserved: (TODO) will generate new spikes conserving the total number of observed spikes (randomly distributed)
    % - jitter: (TODO) will shift existing spikes randomly a given amount (see jitterAmount)
    % amount:
    % Number of surrogate time series to generate for each cell. The more the better. At a bare minimum use 20 for testing purposes. For good estimates you should use at least 1000
    % jitterAmount:
    % - Seconds to shift spikes around (if type = jitter)
    surrogates = struct('enable', true, 'useAllAtOnce', true, 'type', {{'ISIconserved', 'poisson', 'spikeCountConserved', 'jitter'}}, 'amount', 100, 'jitterAmount', 0.1);
    
    % (TODO) Apply a global conditioning on the signal before the inference (see Orlandi, et al (2014). PLoS ONE, 9(6), e98842. [https://doi.org/10.1371/journal.pone.0098842](https://doi.org/10.1371/journal.pone.0098842))
    % enable:
    % If we should use the global conditioning
    % levelEstimation:
    % How to estimate the conditioning level:
    % - auto: will try to automatically estimate the appropiate level based on the global signal distribution
    % - real value: will use this value as a hard threshold and condition below, e.g., 0.3
    % - value pair: will condition using only values within the interval, e.g., [0.2 0.4]
    globalConditioning = struct('enable', false, 'levelEstimation', {{'auto', ''}});
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
  end
end
