function curSortingOrder = getCurrentSortingOrder()
% GETCURRENTSORTINGORDER PENDING
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
  sortMenu = findobj(gcbf, 'Tag', 'sort');
  curSortingOrder = [];
  if(isempty(sortMenu) || ~isvalid(sortMenu))
    return;
  end
  
   % Get the current sorting
  for i = 1:length(sortMenu.Children)
    if(strcmpi(sortMenu.Children(i).Checked, 'on'))
      curSortingOrder = sortMenu.Children(i).Label;
      return;
    end
  end
end