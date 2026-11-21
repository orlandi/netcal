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
    
    % Which population group to import the ROI from (only when importing from another experiment):
    % - none: will import all ROI
    % - ask: will show a pop up window asking from which group you want to import ROIs.
    group = {'none', 'ask'};
    
    % If IDs should be reassigned. If not, ROI IDs will be the sames as the ones in the imported list (if any). Keep in mind that this might result in duplicates
    reassignIDs = true;
    
    % What kind of import to do:
    % - overwrite: any previous ROI list will be removed and replace with the new
    % - append: will try and append the new ROI to any existing list
    importType = {'overwrite', 'append'};
    
    % File to import ROI from - can be a .txt file or an .exp file
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
