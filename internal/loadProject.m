function project = loadProject(varargin)
% LOADPROJECT loads a NETCAL project. If name or folder are not given,
% it will ask for them
%
% USAGE:
%    project = loadProject(varargin)
%
% INPUT optional arguments ('key' followed by its value):
%
%    'name' - string. Name for the new project. Default: empty
%
%    'folder' - string. Path to store the project at. Default: empty
%
%    'verbose' - true/false. If true, outputs verbose information
%
%    'defaultFolder' - default folder on the UI load window.
%
%    'gui' - handle. Set if using the GUI
%
%    'dryRun' true/false. Only check if the project can be lodaded. Do not
%    load anything. Default: false
%
% OUTPUT arguments:
%    project - Structure containing the project parameters
%
% EXAMPLE:
%     project = loadProject();
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
params.verbose = true;
params.folder = [];
params.defaultFolder = pwd;
params.name = [];
params.dryRun = false;
params.pbar = [];
params.gui = [];
params = parse_pv_pairs(params, varargin);
project = [];
if(isempty(params.gui))
  gui = gcbf;
else
  gui = params.gui;
end

if(isempty(params.folder) || isempty(params.name))
  [fileName, pathName] = uigetfile([params.defaultFolder filesep '*.proj'], 'Select project to load');
  if(fileName == 0)
    return;
  end
  if(~ischar(fileName) || ~exist([pathName fileName], 'file'))
    logMsg('Invalid project name', gui, 'e');
    return;
  end
else
  pathName = params.folder;
  fileName = [params.name '.proj'];
end

if(params.dryRun)
  try
    stateVariables = who('-file', [pathName fileName]);
  catch ME
    logMsg('Loading project failed', gui, 'e');
    logMsg(ME.message, gui, 'e');
    return;
  end

  tmpdata = load([pathName fileName], '-mat');
  project = tmpdata;
  if(isfield(project, 'project'))
    logMsg('Project file might be on the old format. Updating', gui, 'w');
    project = project.project;
  end
  % Check if the project has changed folder
  if(~strcmp(pathName, project.folder))
    logMsg('Looks like the project folder has changed. Updating...', gui);
    project.folder = pathName;
    project.folderFiles = [pathName 'projectFiles' filesep];
  end
  if(~strcmp(fileName, [project.name '.proj']))
    logMsg('Looks like the project name has changed. Updating...', gui);
    [~, project.name, ~] = fileparts(fileName);
  end
  return;
end
params = barStartup(params, 'Loading project', true, gui);

try
  stateVariables = who('-file', [pathName fileName]);
catch ME
  logMsg('Loading project failed', gui, 'e');
  logMsg(ME.message, gui, 'e');
  barCleanup(params);
  return;
end
try
  tmpdata = load([pathName fileName], '-mat');
catch ME
  logMsg('Loading project failed', gui, 'e');
  logMsg(ME.message, gui, 'e');
  tmpdata = [];
end
if(isfield(tmpdata, 'project'))
  project = tmpdata.project;
else
  project = tmpdata;
end

if(isempty(project))
  logMsg('Could not load the project', gui, 'e');
  return;
end
% % Now another pass to store the state variables within the project
% for i = 1:length(stateVariables)
%   % Don't save them as state variablese anymore, store them in the project itself
% %   if(~isempty(gcbf))
% %     setappdata(gcbf, stateVariables{i}, tmpdata.(stateVariables{i}));
% %   else
% %     assignin('base', stateVariables{i}, tmpdata.(stateVariables{i}));
% %   end
%   % If its the project also load it here
%   if(~strcmp(stateVariables{i}, 'project'))
%     project.(stateVariables{i}) = tmpdata.(stateVariables{i});
%   end
% end

 % Check if the project has changed folder
if(~strcmp(pathName, project.folder))
  logMsg('Looks like the project folder has changed. Updating...', gui);
  project.folder = pathName;
  project.folderFiles = [pathName 'projectFiles' filesep];
end
if(~strcmp(fileName, [project.name '.proj']))
  logMsg('Looks like the project name has changed. Updating...', gui);
  [~, project.name, ~] = fileparts(fileName);
end


if(params.verbose)
  logMsg(sprintf('Found %d experiments', length(project.experiments)), gui);
  try
    experiment = getappdata(gui, 'experiment');
    if(~isempty(gcbf) && ~isempty(experiment))
      logMsg(sprintf('Current experiment: %s', experiment.name), gui);
    end
  catch
  end
end

%--------------------------------------------------------------------------
barCleanup(params, [], gui);
%--------------------------------------------------------------------------
