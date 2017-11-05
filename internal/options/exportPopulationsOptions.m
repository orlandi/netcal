classdef exportPopulationsOptions < exportBaseOptions
% EXPORTPOPULATIONSOPTIONS Options for exporting traces
%   Class containing the options for exporting traces
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, exportBaseOptions, optionsWindow

  properties
    % Type of export:
    % - full: exports in each column the index of all the ROI
    % - count: exports the number of ROI in each population
    exportPopulationType = {'full', 'count'};
    
    % File name to use
    exportFileName = [pwd 'pop.txt'];
  end
  methods
    function obj = setProjectDefaults(obj, project)
      if(~isempty(project))
        try
          obj.exportFileName = [project.folder filesep 'data' filesep project.name '_DataPopulations.dat'];
        catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
