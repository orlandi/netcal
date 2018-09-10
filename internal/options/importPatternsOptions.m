classdef importPatternsOptions < baseOptions
% IMPORTPATTERNSOPTIONS Options for importing patterns
%   Class containing the options for importing patterns
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also importFilePatterns, baseOptions, optionsWindow

  properties
    % File to import traces from
    fileName = [pwd filesep 'patterns.json'];
    
    % Type of patterns to import
    % - traces: patterns from individual traces
    % - bursts: patterns from bursts (average traces)
    mode = {'traces', 'bursts'};
    
    % If true, will clear the pattern list from the experiment before
    % importing
    removeAllPreviousPatterns@logical = false;
    
    % If true, will remove identical patterns (those with the same name and a correlation threshold above 0.999)
    removeIdenticalPatterns@logical = true;
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.fileName = fullfile(experiment.folder, filesep, 'patterns.json');
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder');
        obj.fileName = fullfile(exp.folder, filesep, 'patterns.json');
      end
    end
  end
end
