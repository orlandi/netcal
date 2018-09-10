classdef importROIoptions < baseOptions
% IMPORTROIOPTIONS Options for importing ROI
%   Class containing the options for importing patterns
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also importFilePatterns, baseOptions, optionsWindow

  properties
    
    % Where to import the ROI from:
    % - experiment: from a previouslly processed experiment
    % - external file: from an external (previouslly exported) ROI list
    origin = {'experiment', 'external file'};
    
    % Experiment to import from
    experiment  = {''};
    
    % File to import ROI from
    file = [pwd filesep 'ROI.txt'];

  end
  methods
    function obj = setProjectDefaults(obj, project)
      if(~isempty(project) && isstruct(project))
        obj.experiment = project.experiments;
        obj.file = [project.folder filesep 'ROI.txt'];
      end
    end
  end
end
