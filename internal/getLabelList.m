function [labelList, uniqueLabels, labelsCombinations, labelsCombinationsNames, experimentsPerCombinedLabel] = getLabelList(project, varargin)
% Cell list, with {1x2} cells with contents experiment ID (absolute) and
% label
  %gui = gcbf;
  %project = getappdata(gui, 'project');
  if(isempty(project))
    logMsg('Error loading data from the current project', 'e');
    labelList = [];
    return;
  end
  if(length(varargin) >= 1 && ~isempty(varargin{1}))
      selection = varargin{1};
  else
      selection = 1:length(project.experiments);
  end
  
  labelList = {};
  labelsCombinations = {};
  labelsCombinationsNames = {};
  for i = 1:length(selection)
    curLabels = project.labels{selection(i)};
    if(isempty(curLabels))
      %labelList{end+1} = {selection(i), ''};
      continue;
    end
    curLabels = strtrim(strsplit(curLabels, ','));
    for j = 1:length(curLabels)
      labelList{end+1} = {selection(i), curLabels{j}};
    end
  end
  uniqueLabels = unique(cellfun(@(x)x{2}, labelList, 'UniformOutput', false));
  for i = 1:length(uniqueLabels)
    curList = pick(uniqueLabels, i, '');
    for j = 1:size(curList, 1)
      labelsCombinations{end+1} = curList(j, :);
      labelsCombinationsNames{end+1} = strjoin(labelsCombinations{end}, ', ');
    end
  end
  % For each new joint label, the present experiments
  experimentsPerCombinedLabel = cell(size(labelsCombinations));
  for i = 1:length(selection)
    curLabels = project.labels{selection(i)};
    if(isempty(curLabels))
      continue;
    end
    curLabels = sort(strtrim(strsplit(curLabels, ',')));
    for j = 1:size(labelsCombinations, 2)
      curCombo = labelsCombinations{j};
      %for k = 1:length(curCombo)
        if(isequal(curLabels, curCombo) || (length(intersect(curCombo, curLabels)) == length(curCombo)))
          experimentsPerCombinedLabel{j}{end+1} = selection(i);
        end
      %end
    end
  end
  % Clear empty labels
  invalid = find(~cellfun(@(x)length(x),experimentsPerCombinedLabel));
  experimentsPerCombinedLabel(invalid) = [];
  labelsCombinationsNames(invalid) = [];
end
