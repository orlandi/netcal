classdef spikeDetectConflictsOptions < baseOptions
% SPIKEDETECTCONFLICTSOPTIONS Base options for detecting spike conflicts
%   Class containing the options for detecting spike conflicts
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also spikeDetectConflicts, baseOptions, optionsWindow

  properties
    % Group to perform function on:
    % - none: will use all traces
    % - all: will recursively go through all defined groups
    % - group parent: will iterate through all the group submembers
    % - group member: will only use the members of this group
    group = {'none', ''};
    
    % Groups of patterns that should not contain spikes
    conflictingGroups = {'none', ''};
    
    % Number of seconds to expand events on the conflicting group (in both directions, e.g., 5 will remove any spikes within 5 seconds of events in the conflicting group
    conflictingGroupExpansion = 0;
    
    % Groups of patterns that should contain spikes (will remove any spikes from the conflicting groups that are also present in this group)
    exclusionGroups = {'none', ''};
    
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
        end
        if(length(obj.group) == 1)
          obj.group{end+1} = '';
        end
      end
      if(~isempty(experiment) && isstruct(experiment))
        try
          [~, basePatternList] = generatePatternList(experiment);
          if(~isempty(basePatternList))
            obj.conflictingGroups = basePatternList';
            obj.exclusionGroups = basePatternList';
          end
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        warning('off','MATLAB:load:variableNotFound');
        exp = load(experiment, '-mat', 'patternFeatures', 'fps', 'importedPatternFeatures', 'learningEventListPerTrace', 'burstPatterns', 'importedBurstPatternFeatures');
        warning('on','MATLAB:load:variableNotFound');
        [~, basePatternList] = generatePatternList(exp);
        if(~isempty(basePatternList))
          obj.conflictingGroups = basePatternList';
          obj.exclusionGroups = basePatternList';
        end
      end
    end
  end
end
