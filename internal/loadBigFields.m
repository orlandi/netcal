function [experiment, success] = loadBigFields(experiment, varargin)
% LOADBIGFIELDS loads a set of big fields
%
% USAGE:
%    [experiment, success] = loadBigFields(experiment, varargin)
%
% INPUT arguments:
%    experiment - The experiment structure
%
% INPUT optional arguments:
%    bigFields - list of big field names to load
%
% OUTPUT arguments:
%    experiment - structure containing the experiment parameters
%
%    success - true if traces were loaded or partially loaded
%
% EXAMPLE:
%     experiment = loadBigFields(experiment, 'rawTraces')
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment

success = false;

if(nargin < 2)
  bigFields = getBigFields();
else
  bigFields = varargin{1};
end

for i = 1:length(bigFields)
  if(isfield(experiment, bigFields{i}) && ischar(experiment.(bigFields{i})))
    dataFolder = [experiment.folder 'data' filesep];
    rawFile = [dataFolder experiment.name '_' bigFields{i} '.dat'];

    try
      load(rawFile, '-mat');
      success = true;
    catch
      success = false;
      if(strcmpi(bigFields{i}, 'baseLine'))
        logMsg([bigFields{i} ' not found. Assuming it doesnt exist anymore'],'w');
        experiment = rmfield(experiment, bigFields{i});
        continue;
      end
      logMsg([bigFields{i} ' file missing. Looking for alternatives...'],'w');
      fileList = dir(dataFolder);
      for j = 1:length(fileList)
        if(strfind(fileList(j).name, ['_' bigFields{i} '.dat']))
          logMsg(['Using: ' dataFolder fileList(j).name],'w');
          load([dataFolder fileList(j).name], '-mat');
          success = true;
          experiment.(bigFields{i}) = eval(bigFields{i});
          experiment = saveExperiment(experiment, 'pbar', 0);
          break;
        end
      end
      if(~success)
        logMsg(['Could not find ' bigFields{i} '. Please locate the file yourself'], 'w');
        [fileName, pathName] = uigetfile([experiment.folder filesep rawFile], ['Find ' bigFields{i} ' file']);
        fullFile = [pathName fileName];
        if(fullFile(1) == 0 || ~exist(fullFile, 'file'))
          logMsg(['Invalid ' bigFields{i} ' file'], 'e');
          success = false;
          return;
        else
          try
            load(fullFile, '-mat');
            success = true;
            experiment.(bigFields{i}) = eval(bigFields{i});
            experiment = saveExperiment(experiment, 'pbar', 0);
          catch
          end
        end
      end
    end
    experiment.(bigFields{i}) = eval(bigFields{i});
  %elseif(isfield(experiment, bigFields{i}) && isnumeric(experiment.(bigFields{i})))
  elseif(isfield(experiment, bigFields{i}))
    success = true;
  end
end