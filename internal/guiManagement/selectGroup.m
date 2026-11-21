function selectGroup(~, ~, groupType, groupIdx, varargin)
% SELECTGROUP PENDING
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

  if(nargin >= 5)
    newSorting = varargin{1};
  else
    newSorting = [];
  end
  if(nargin >= 6)
    gui = varargin{2};
  else
    gui = [];
  end
  % First deselect everything and store current selection
  %[curGroupType, curGroupIdx] = getCurrentGroup();
  groupList = findobj(gcf, '-regexp','Tag', 'selection');
  for i = 1:length(groupList)
    groupList(i).Checked = 'off';
  end
  for i = 1:length(groupList)
    groupName = strsplit(groupList(i).Tag, ':');
    if(length(groupName) == 3 && strcmpi(groupName{2}, groupType) && strcmpi(groupName{3}, num2str(groupIdx)))
      groupList(i).Checked = 'on';
      updateSortingMethod([], [], newSorting, gui);
      return;
    end
  end
  % If we got here, we could not find the group
  logMsg('Current selection no longer valid, trying to go back to everything and ROI ordering', 'e');
  % Write them here to avoid infinite recursion if anything goes wrong
  groupType = 'everything';
  groupIdx = 1;
  for i = 1:length(groupList)
    groupName = strsplit(groupList(i).Tag, ':');
    if(length(groupName) == 3 && strcmpi(groupName{2}, groupType) && strcmpi(groupName{3}, num2str(groupIdx)))
      groupList(i).Checked = 'on';
      updateSortingMethod([], [], 'ROI', gui);
      return;
    end
  end
  
end