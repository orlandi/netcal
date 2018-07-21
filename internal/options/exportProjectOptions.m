classdef exportProjectOptions < baseOptions
% EXPORTPROJECTOPTIONS Options for exporting projects
%   Class containing the possible ways to export projects
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWIndow

  properties
    % Choose what movie to preprocess (standard or denoised)
    exportFolder = pwd;
    
    % Name of the exported project
    newProjectName = 'exportedProject';
    
    % If true, will only export the checked experiments
    exportOnlyCheckedExperiments = false;
    
    % If true, it will also create a zip file with ALL the contents of the exported project folder.
    createZip = false;
  end
end
