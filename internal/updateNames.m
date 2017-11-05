function experiment = updateNames(experiment, oldName, newName, skipFields)
% UPDATENAMES updates the names in all strings inside an experiment
% structure
%
% USAGE:
%    experiment = updateNames(experiment, oldName, newName, skipFields))
%
% INPUT arguments:
%    experiment - the experiment structure
%
%    oldName - string to be replaced
%
%    newNam - new string to use instead of old one
%
%    skipFields - do not update these fields
%
%
% OUTPUT arguments:
%    experiment - structure containing the experiment parameters
%
% EXAMPLE:
%     experiment = loadExperiment(filename)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

if(nargin < 4)
  skipFields = [];
end

% Rmemove skipFields
validFields = fieldnames(experiment);
for i = 1:length(skipFields)
  [valid, idx] = ismember(skipFields{i}, validFields);
  if(valid)
    validFields(idx) = [];
  end
end
for i = 1:length(validFields)
  if(ischar(experiment.(validFields{i})))
    experiment.(validFields{i}) = strrep(experiment.(validFields{i}), oldName, newName);
  end
end
