function menuHandle = generateSelectionMenu(experiment, parent)
% GENERATESLECTIONMENU PENDING
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

  menuHandle = struct;
  menuHandle.root = uimenu(parent, 'Label', 'Selection', 'Tag', 'selection');
  selectionNames = fieldnames(experiment.traceGroupsNames);
  for i = 1:length(selectionNames)
    menuHandle.(selectionNames{i}).root = uimenu(menuHandle.root, ...
                                                 'Tag', sprintf('selection:%s:%d', selectionNames{i}, 1), ...
                                                 'Label', selectionNames{i});
    menuHandle.(selectionNames{i}).list = [];
  end
  
  % Again
  for i = 1:length(selectionNames)
    curSelection = selectionNames{i};
    if(~isfield(experiment.traceGroups, curSelection))
      continue;
    end
    if(isempty(menuHandle.(curSelection).list))
      curMenu = menuHandle.(curSelection).root;
    else
      curMenu = menuHandle.(curSelection).list;
    end
    % Delete previous list
    for j = 1:length(curMenu)
      if(length(curMenu) > 1)
        delete(curMenu(j));
      end
    end
    % Add entries
    curList = [];
    groupNames = experiment.traceGroupsNames.(curSelection);
    if(length(groupNames) > 1)
      % Since this is a subgroup, remove the idx from the parents tag
      menuHandle.(curSelection).root.Tag = sprintf('selection:%s', selectionNames{i});
      for j = 1:length(groupNames)
        fullString = sprintf('%d. %s (%d traces)', ...
          j, groupNames{j}, length(experiment.traceGroups.(curSelection){j}));
        if(length(experiment.traceGroups.(curSelection){j}) >= 1)
          enabled = 'on';
        else
          enabled = 'off';
        end
        curList = [curList; ...
          uimenu(menuHandle.(curSelection).root, ...
                 'Label', fullString, 'Checked', 'off', 'Enable', enabled, ...
                 'Tag', sprintf('selection:%s:%d', curSelection, j), ...
                 'Callback', {@selectGroup, curSelection, j})];
      end
    elseif(length(groupNames) == 1)
      fullString = sprintf('%s (%d traces)', ...
                           curSelection, length(experiment.traceGroups.(curSelection){1}));
      if(length(experiment.traceGroups.(curSelection){j}) >= 1)
        enabled = 'on';
      else
        enabled = 'off';
      end
      menuHandle.(curSelection).root.Label = fullString;
      menuHandle.(curSelection).root.Checked = 'off';
      menuHandle.(curSelection).root.Enable = enabled;
      menuHandle.(curSelection).root.Callback = {@selectGroup, curSelection, j};
    else
      fullString = [curSelection '(empty)'];
      menuHandle.(curSelection).root.Label = fullString;
      menuHandle.(curSelection).root.Enable = 'off';
    end
    menuHandle.(curSelection).list = curList;
  end
  % Now that we are done, reassign the callbacks
  for i = 1:length(selectionNames)
    curSelection = selectionNames{i};
    for j = 1:length(menuHandle.(curSelection).list)
      menuHandle.(curSelection).list(j).Callback = {@selectGroup, curSelection, j};
    end
  end
  
end