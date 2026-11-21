classdef exportStatisticsOptions < baseOptions
% EXPORTSTATISTICSOPTIONS # Main class to export statistics
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also exportStatistics, baseOptions, optionsWindow

  properties (Abstract)
    % Chosen statistic to plot
    statistic;
  end
  
  properties (Abstract, Constant = true, Hidden = true)
    % Fields from which experiment data will be pulled (always loaded: traceGroups, traceGroupsNames, name, folder, ROI). Leave empty to load all fields
    loadFields;
  end
  
  properties
    % How to run this function on the pipeline:
    % - experiment: will run separately on each checked experiments (results in one file per experiment)
    % - project: will run simultaneously on all checked experiments (results in one file with all experiments)
    pipelineMode = {'experiment', 'project'};
    
    % Group to perform function on:
    % - none: will NOT use groups, i.e., use all elements
    % - ask: will show a popup window where the user can select the interested groups (useful for discontinous selection). You have to write 'ask' yourself, it will not show up within the options
    % - all: will use all defined groups
    % - group parent: will uuse all the group submembers
    % - group member: will only use the members of this group
    group = {'none'};
    
    % How to export the data:
    % - full: will export all the data, i.e., one row per ROI (or variable).
    % - statistics: will export summary statistics, i.e., moments, min, max, quartiles, etc.
    exportMode = {'full', 'summary'};
    
    % If true will turn any zero values into NaNs (so they are not used for the statistics). Useful when working with rates and things like that. NOTE: if true, zeros are converted to NaN as soon as they are measured, so any summary statistic will report 0 zeros
    zeroToNan = true;
    
    % Export options
    % NaNtoBlank:
    % If true, NaN will be displayed as an empty cell
    % dataFormat:
    % What formatting operator to apply when writting the file (see fprintf for details, default is floating point with 5 decimals)
    % includeROI:
    % If yes, for each experiment will include a column with the ROI ID. If index is used, it will return the index on the array not the ID (only for advanced users)
    % baseFolder:
    % Default folder to save the file (only for experiment Pipeline, project Pipeline always uses the project folder)
    % fileTag:
    % Tag to append to the name of the saved figure
    % saveExperiment:
    % If the experiment should be saved after this function is run. If disabled, options might not be memorized, but might speed up running a batch export
    exportOptions = struct('NaNtoBlank', false, 'dataFormat', '%.5f', 'includeROI', {{'no', 'yes', 'index'}}, 'baseFolder', {{'experiment', 'project'}}, 'fileTag', '', 'saveExperiment', true);
  end
  
  methods
    % For the defaults need to redo the groups and the statistic based on a case by case basis
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.group = getExperimentGroupsNamesFull(experiment);
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e'); %#ok<SPRINTFN>
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
      % Always add the option all and ask to the statistic list
      obj.statistic = [obj.statistic(:)', 'all', 'ask'];
    end
    
    function obj = setProjectDefaults(obj, project) %#ok<INUSD>
      
    end
  end
end
