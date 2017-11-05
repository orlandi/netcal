function [success, curOptions, experiment] = preloadOptions(experiment, optionsClass, gui, allowChanges, shouldExist)
% PRELOADOPTIONS loads a given type of options for an experiment. If the
% experiment has the class defined, it will load it, if not, it will check
% in the project, and if not, it will load default options.
%
% USAGE:
%    [success, curOptions, experiment] = preloadOptions(experiment, optionsClass, gui, allowChanges, shouldExist)
%
% INPUT arguments:
%
%    experiment - structure obtained from loadExperiment()
%
%    optionsClass - base class to load
%
%    gui - handle to the GUI (it will load the project from there)
%
%    allowChanges - to open the options window to make changes (true/false)
%
%    shouldExist - will output a warning if the class does not already
%    exist
%
% OUTPUT arguments:
%
%    success - if everything went ok (true/false)
%
%    curOptions - class with the updated options list
%
%    experiment - the experiment structure (if success, it should come attached with the new options class)
%
% EXAMPLE:
%    [success, curOptions, experiment] = preloadOptions(experiment, learningOptions, gcbf, true, false)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also baseOptions, optionsWindow

if(nargin < 4)
  allowChanges = true;
end
if(nargin < 5)
  shouldExist = false;
end

optionsClassName = class(optionsClass);
success = true;

% First try to load from the experiment
if(~isempty(experiment) && isfield(experiment, [optionsClassName 'Current']))
  optionsClassCurrent = experiment.([optionsClassName 'Current']);
  % Check if the class is wierd
  if(~isa(optionsClassCurrent, optionsClassName))
    logMsg(['Something went wrong loading ' optionsClassName '. Using defaults'], 'w');
    optionsClassCurrent = eval(optionsClassName);
  end
  
else
  if(~isempty(gui))
    project = getappdata(gui, 'project');
      if(~isempty(project) && isfield(project, [optionsClassName 'Current']))
        % If not, try to load from the project
        optionsClassCurrent = project.([optionsClassName 'Current']);
      else
        % If not, try to load from the environment
        optionsClassCurrent = getappdata(gui, [optionsClassName 'Current']);
      end
  else
    optionsClassCurrent = [];
  end
  if(~isempty(optionsClassCurrent) && shouldExist)
    logMsg(['Previous ' optionsClassName ' for this experiment not found. Using latest used values for the current project'], 'w');
  elseif(isempty(optionsClassCurrent) && shouldExist)
    logMsg(['No previous ' optionsClassName ' found. Using default values'], 'w');
  end
end

if(isempty(optionsClassCurrent))
  curOptions = optionsClass;
else
  curOptions = optionsClassCurrent;
end
% Process experiment defaults
%curOptions = curOptions.setExperimentDefaults(experiment);

if(allowChanges)
  [success, curOptions] = optionsWindow(curOptions, 'experiment', experiment);
else
  curOptions = curOptions.setDefaults;
end
if(success)
  experiment.([optionsClassName 'Current']) = curOptions;
end
