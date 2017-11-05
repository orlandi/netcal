function [success, curOptions] = preloadMultipleOptions(experiment, optionsClass, gui, allowChanges, shouldExist, windowTitle)
% PRELOADMULTIPLEOPTIONS loads a given type of options for an experiment. If the
% experiment has the class defined, it will load it, if not, it will check
% in the project, and if not, it will load default options.
%
% USAGE:
%    [success, curOptions] = preloadOptions(experiment, optionsClass, gui, allowChanges, shouldExist)
%
% INPUT arguments:
%
%    experiment - structure obtained from loadExperiment()
%
%    optionsClass - list of base classes to load
%
%    gui - handle to the GUI (it will load the project from there)
%
%    allowChanges - to open the options window to make changes (true/false)
%
%    shouldExist - will output a warning if the class does not already
%    exist
%
%    windowTitle - title for the options window (if allowed changes)
%
% OUTPUT arguments:
%
%    success - if everything went ok (true/false)
%
%    curOptions - class list with the updated options list
%
% EXAMPLE:
%    [success, curOptions] = preloadOptions(experiment, learningOptions, gcbf, true, false, 'Select parameters')
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
if(nargin < 6)
  windowTitle = 'Configure options';
end
curOptions = cell(length(optionsClass), 1);
for it = 1:length(optionsClass)
  optionsClassName = class(optionsClass{it});
  success = true;

  if(~isempty(experiment) && isfield(experiment, [optionsClassName 'Current']))
    optionsClassCurrent = experiment.([optionsClassName 'Current']);
  else
    optionsClassCurrent = getappdata(gui, [optionsClassName 'Current']);
    if(~isempty(optionsClassCurrent) && shouldExist)
      logMsg(['Previous ' optionsClassName ' for this experiment not found. Using latest used values for the current project'], 'w');
    elseif(isempty(optionsClassCurrent) && shouldExist)
      logMsg(['No previous ' optionsClassName ' found. Using default values'], 'w');
    end
  end

  if(isempty(optionsClassCurrent))
    curOptions{it} = optionsClass{it};
  else
    curOptions{it} = optionsClassCurrent;
  end
end
if(allowChanges)
  [success, curOptions] = optionsWindowTabbed(curOptions, windowTitle);
else
  for it = 1:length(optionsClass)
    curOptions{it} = curOptions{it}.setDefaults;
  end
end
