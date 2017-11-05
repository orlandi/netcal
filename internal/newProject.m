function project = newProject(varargin)
% NEWPROJECT creates a new NETCAL project. If name or folder are not given,
% it will ask for them
%
% USAGE:
%    project = newProject(varargin)
%
% INPUT optional arguments ('key' followed by its value):
%
%    'name' - string. Name for the new project. Default: empty
%
%    'folder' - string. Path to store the project at. Default: empty
%
%    'verbose' - true/false. If true, outputs verbose information
%
%    'filesFolder' - Where to store project files (relative to the main
%    folder). Default: projectFiles
%
%    'gui' - handle. Set if using the GUI
%
% OUTPUT arguments:
%    project - Structure containing the project parameters
%
% EXAMPLE:
%     project = newProject();
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.verbose = true;
params.folder = [];
params.name = [];
params.filesFolder = 'projectFiles';
params = parse_pv_pairs(params, varargin);

project = [];
  
if(isempty(params.folder) || isempty(params.name))
  [fileName, pathName] = uiputfile('*.proj', 'Select project name and root folder'); 
  if(~fileName)
    logMsg('Invalid project name', 'e');
    return;
  end
  if(exist([pathName, filesep fileName], 'file'))
    logMsg('Project already exists', 'e');
    return;
  end
  [~, project.name, ~] = fileparts(fileName);
  project.folder = pathName;
  project.experiments = {};
  project.checkedExperiments = [];
  project.labels = {};
  project.folderFiles = [project.folder params.filesFolder filesep];
end
    
if(params.verbose)
  logMsg('');
  logMsg('----------------------------------');
  MSG = ['Starting new project ' fileName];
  logMsg([datestr(now, 'HH:MM:SS'), ' ', MSG], 'w');
  logMsg('----------------------------------');
end

end