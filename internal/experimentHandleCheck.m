function [experiment, success] = experimentHandleCheck(experiment)
% EXPERIMENTHANDLECHECK checks if the handle is valid and updates it accordingly
%
% USAGE:
%    experiment = experimentHandleCheck(experiment)
%
% INPUT arguments:
%    experiment - The experiment structure
%
% OUTPUT arguments:
%    experiment - structure containing the experiment parameters
%
%    success - true if the handle is valid
%
% EXAMPLE:
%     experiment = experimentHandleCheck(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment

success = true;
if(experiment.handle(1) == 0 || ~exist(experiment.handle, 'file'))
  if(experiment.handle(1) ~= 0)
    try %#ok<TRYNC>
      if(strcmp(experiment.handle, 'dummy'))
        return;
      end
    end
    [~, fpb, fpc] = fileparts(experiment.handle);
    logMsg(sprintf('Could not find %s ', experiment.handle), 'e');
    if(exist(experiment.folder, 'dir'))
      [fileName, pathName] = uigetfile([experiment.folder filesep '*' fpc], 'Find recording location');
    else
      [fileName, pathName] = uigetfile(['*' fpc], 'Find recording location');
      %[fileName, pathName] = uigetfile('*.*', 'Find recording location');
    end
  else
    if(exist(experiment.folder, 'dir'))
      [fileName, pathName] = uigetfile([experiment.folder filesep '*.*'], 'Find recording location');
    else
      [fileName, pathName] = uigetfile('*.*', 'Find recording location');
    end
  end
  experiment.handle = [pathName fileName];
  if(experiment.handle(1) == 0 || ~exist(experiment.handle, 'file'))
    logMsg('Invalid experiment handle', 'e');
    success = false;
    return;
  else
    logMsg(sprintf('experiment handle updated to %s ', experiment.handle));
    experiment = saveExperiment(experiment, 'pbar', 0);
  end
end
