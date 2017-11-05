function experiment = checkGroups(experiment)
% CHECKGROUPS Checks and updates the internal structure of experiments
% groups, so it matches the new format
%
% USAGE:
%   experiment = checkGroups(experiment)
%
% INPUT arguments:
%   experiment - structure containing an experiment
%
% OUTPUT arguments:
%   experiment - structure containing an experiment
%
% EXAMPLE:
%   experiment = checkGroups(experiment)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also viewTraces

% Basically move data from column 1 to structure on column 2 with
% substructure from column 3
fieldList = {'groupTraces', 'traceGroups', 'classifier' ;
             'HCG', 'traceGroups', 'HCG';
             'trainingGroupNames', 'traceGroupsNames', 'classifier';
             'manualGroupNames', 'traceGroupsNames', 'manual'};


for i = 1:size(fieldList, 1)
  % First try to create the structure
  if(isfield(experiment, fieldList{i, 1}) && ~isfield(experiment, fieldList{i, 2}))
    experiment.(fieldList{i, 2}) = struct;
  end
  % Now try to pass values
  if(isfield(experiment, fieldList{i, 1}) && ~isfield(experiment.(fieldList{i, 2}), fieldList{i, 3}))
    experiment.(fieldList{i, 2}).(fieldList{i,3}) = experiment.(fieldList{i, 1});
  end
end

% Now with 4
fieldList = {'groupTracesSimilarityOrder', 'traceGroupsOrder', 'similarity', 'classifier' ;
             'similarityOrder', 'traceGroupsOrder', 'similarity', 'everything'};
for i = 1:size(fieldList, 1)
  % First try to create the structure
  if(isfield(experiment, fieldList{i, 1}) && ~isfield(experiment, fieldList{i, 2}))
    experiment.(fieldList{i, 2}) = struct;
  end
  % Now the second level structure
  if(isfield(experiment, fieldList{i, 1}) && ~isfield(experiment.(fieldList{i,2}), fieldList{i, 3}))
    experiment.(fieldList{i, 2}).(fieldList{i, 3}) = struct;
  end
  % Now try to pass values
  if(isfield(experiment, fieldList{i, 1}) && ~isfield(experiment.(fieldList{i, 2}).(fieldList{i, 3}), fieldList{i, 4}))
    experiment.(fieldList{i, 2}).(fieldList{i,3}).(fieldList{i,4}) = experiment.(fieldList{i, 1});
  end
end
% Create required fields
if(~isfield(experiment, 'traceGroups'))
  experiment.traceGroups = struct;
end
if(~isfield(experiment, 'traceGroupsNames'))
  experiment.traceGroupsNames = struct;
end
if(~isfield(experiment, 'traceGroupsOrder'))
  experiment.traceGroupsOrder = struct;
end
if(~isfield(experiment.traceGroupsOrder, 'similarity'))
  experiment.traceGroupsOrder.similarity = struct;
end
if(~isfield(experiment.traceGroupsOrder, 'ROI'))
  experiment.traceGroupsOrder.ROI = struct;
end

if(isfield(experiment.traceGroups, 'classifier') && isfield(experiment.traceGroupsNames, 'classifier'))
  if(~iscell(experiment.traceGroupsNames.classifier))
    experiment.traceGroupsNames.classifier = {};
  end
  if(length(experiment.traceGroups.classifier) ~= length(experiment.traceGroupsNames.classifier))
    [~, smallest] = min([size(experiment.traceGroups.classifier,1), size(experiment.traceGroupsNames.classifier,1)]);
    if(smallest == 1)
      experiment.traceGroups.classifier{length(experiment.traceGroupsNames.classifier)} = 1;
    else
      experiment.traceGroupsNames.classifier{length(experiment.traceGroups.classifier)} = [];
    end
  end
end

% And the HCG group names (not anymore
% if(isfield(experiment.traceGroups,'HCG'))
%   experiment.traceGroupsNames.HCG = cell(length(experiment.traceGroups.HCG), 1);
%   for i = 1:length(experiment.traceGroups.HCG)
%     experiment.traceGroupsNames.HCG{i} = num2str(i);
%   end
% end
% Now add the everything to all groups
%if(isfield(experiment, 'ROI') && ~isfield(experiment.traceGroups,'everything') && (length(experiment.traceGroups.everything) ~= length(experiment.ROI)))
if(isfield(experiment, 'ROI'))
  if(isfield(experiment, 'traces') && ~ischar(experiment.traces) && (length(experiment.ROI) ~= size(experiment.traces, 2)))
    logMsg('Inconsistency between number of ROIs and traces detected', 'e');
    experiment.traceGroups.everything = {1:size(experiment.traces, 2)};
  else
    experiment.traceGroups.everything = {1:length(experiment.ROI)};
  end
end
%end
if(~isfield(experiment.traceGroupsNames,'everything'))
  experiment.traceGroupsNames.everything = {'everything'};
end
if(isfield(experiment.traceGroupsOrder.similarity, 'everything') && ~iscell(experiment.traceGroupsOrder.similarity.everything))
  experiment.traceGroupsOrder.similarity.everything = {experiment.traceGroupsOrder.similarity.everything};
end
% Now add the ROI order to all groups
if(~isfield(experiment.traceGroupsOrder,'ROI'))
  experiment.traceGroupsOrder.ROI = struct;
end
selectionNames = fieldnames(experiment.traceGroups);
for i = 1:length(selectionNames)
  groupNames = experiment.traceGroupsNames.(selectionNames{i});
  if(~isfield(experiment.traceGroupsOrder.ROI, selectionNames{i}))
    experiment.traceGroupsOrder.ROI.(selectionNames{i}) = cell(length(groupNames), 1);
  end
  if(length(groupNames) > length(experiment.traceGroups.(selectionNames{i})))
    experiment.traceGroups.(selectionNames{i}){length(groupNames)} = [];
  end
  for j= 1:length(groupNames)
    if(length(experiment.traceGroups.(selectionNames{i})) >= j)
      experiment.traceGroupsOrder.ROI.(selectionNames{i}){j} = experiment.traceGroups.(selectionNames{i}){j};
    end
  end
end



