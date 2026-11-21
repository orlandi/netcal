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
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

if(nargin < 4)
  skipFields = [];
end

% Rmemove skipFields
% validFields = fieldnames(experiment);
% for i = 1:length(skipFields)
%   [valid, idx] = ismember(skipFields{i}, validFields);
%   if(valid)
%     validFields(idx) = [];
%   end
% end
% for i = 1:length(validFields)
%   if(ischar(experiment.(validFields{i})))
%     experiment.(validFields{i}) = strrep(experiment.(validFields{i}), oldName, newName);
%   end
% end
% Let's use bigFields list instead
bigFields = getBigFields();
for it = 1:length(bigFields)
  % Skip some fields
  if(~isempty(skipFields) && any(ismember(skipFields, bigFields{it})))
    continue;
  end
  if(isfield(experiment, bigFields{it}) && ischar(experiment.(bigFields{it})))
    experiment.(bigFields{it}) = strrep(experiment.(bigFields{it}), oldName, newName);
  end
end