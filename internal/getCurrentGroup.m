function [groupType, groupIdx] = getCurrentGroup()
% GETCURRENTGROUP
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
	
  groupList = findobj(gcf, '-regexp','Tag', 'selection');
  groupType = [];
  groupIdx = [];
  for i = 1:length(groupList)
    if(strcmpi(groupList(i).Checked, 'on'))
      strList = strsplit(groupList(i).Tag, ':');
      groupType = strList{2};
      groupIdx = str2num(strList{3});
      return;
    end
  end
end