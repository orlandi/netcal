classdef exportSpikesOptions < baseOptions
% EXPORTSPIKESOPTIONS Options for exporting spikes
%   Class containing the options for spike exports
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also exportSpikes, baseOptions, optionsWindow

  properties
    % Export type
    exportType = {'txt', 'csv'};

    % Subpopulation to export (leave empty for doing it on every ROI)
    subpopulation = {'everything', ''};
    
     % Only exports spikes within the given temporal subset
    subset = [0 600];
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.subpopulation = getExperimentGroupsNames(experiment);
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
        try
          obj.subset = [0 round(experiment.totalTime)];
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        warning('off', 'MATLAB:load:variableNotFound');
        exp = load(experiment, '-mat', 'folder', 'name', 'traceGroups', 'traceGroupsNames', 'totalTime');
        warning('on', 'MATLAB:load:variableNotFound');
        pops = getExperimentGroupsNames(exp);
        if(~isempty(pops))
          obj.subpopulation = pops;
        end
        try
          obj.subset = [0 round(exp.totalTime)];
        catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
