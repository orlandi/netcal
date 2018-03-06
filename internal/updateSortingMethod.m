function updateSortingMethod(~, ~, desiredSorting, gui, varargin)

  if(nargin < 4)
    gui = gcbf;
  end
  if(isempty(gui))
    gui = gcf;
  end
  obj = gui;
  
  %if(isempty(gcbf))
  %  obj = gcf;
  %end
  if(isempty(obj))
    return;
  end
  if(length(varargin) >= 1)
    experiment = varargin{1};
  else
    experiment = getappdata(obj, 'experiment');
  end
  if(isempty(experiment))
    return;
  end
  sortMenu = findobj(obj, 'Tag', 'sort');
  %if(isempty(sortMenu) || ~isvalid(sortMenu))
  %  return;
  %end
  [groupType, idx] = getCurrentGroup();
  
  if(isempty(groupType))
    desiredSorting = 'ROI';
    groupType = 'everything';
    idx = 1;
    logMsg('1. Current group is empty. Going back to everything with ROI sorting', 'w');
  end
  if(isempty(desiredSorting))
    desiredSorting = getCurrentSortingOrder();
  end
  if(isempty(desiredSorting))
    desiredSorting = 'ROI';
  end
  if(isstruct(desiredSorting))
    desiredSorting = 'ROI';
  end
  % Now let's check if the order exists and check it
  if(isfield(experiment, 'traceGroupsOrder') && isfield(experiment.traceGroupsOrder, desiredSorting) && isfield(experiment.traceGroupsOrder.(desiredSorting), groupType))
    if(isempty(experiment.traceGroupsOrder.(desiredSorting).(groupType)) || idx > length(experiment.traceGroupsOrder.(desiredSorting).(groupType)))
      desiredSorting = 'ROI';
      groupType = 'everything';
      idx = 1;
      currentOrder = experiment.traceGroupsOrder.ROI.(groupType){idx};
      logMsg('3. Current group is no longer valid. Going back to everything with ROI sorting', 'w');
      selectGroup([], [], groupType, idx, 'ROI');
    else
      currentOrder = experiment.traceGroupsOrder.(desiredSorting).(groupType){idx};
    end
  else
    if(isempty(groupType))
      desiredSorting = 'ROI';
      groupType = 'everything';
      idx = 1;
      currentOrder = experiment.traceGroupsOrder.ROI.(groupType){idx};
      logMsg('4. Current group is no longer valid. Going back to everything with ROI sorting', 'w');
      selectGroup([], [], groupType, idx, 'ROI');
    else
      logMsg(['5. Could not order ' groupType ' by ' desiredSorting '. Ordering by ROI instead'], 'w');
      currentOrder = experiment.traceGroupsOrder.ROI.(groupType){idx};
    end
  end
  % Check that everything is ok. If not, go to everything and ROI
  if(isempty(currentOrder))
    desiredSorting = 'ROI';
    groupType = 'everything';
    idx = 1;
    currentOrder = experiment.traceGroupsOrder.ROI.(groupType){idx};
    logMsg('6. Current group is no longer valid. Going back to everything with ROI sorting', 'w');
    selectGroup([], [], groupType, idx, 'ROI');
  end
  
  setappdata(gui, 'currentOrder', currentOrder);
  resizeHandle = getappdata(gcf, 'ResizeHandle');
  if(isa(resizeHandle,'function_handle'))
    resizeHandle([], []);
  end
  if(isempty(sortMenu) || ~isvalid(sortMenu))
    return;
  end
  if(~isfield(sortMenu, 'Children') && isempty(sortMenu.Children))
    return;
  end
  % Now check the right sortMenu
  for i = 1:length(sortMenu.Children)
    if(~strcmpi(sortMenu.Children(i).Label, desiredSorting))
      sortMenu.Children(i).Checked = 'off';
      if(isfield(experiment, 'traceGroupsOrder') && ...
          isfield(experiment.traceGroupsOrder, sortMenu.Children(i).Label) && ...
          isfield(experiment.traceGroupsOrder.(sortMenu.Children(i).Label), groupType) && ...
         ~isempty(experiment.traceGroupsOrder.(sortMenu.Children(i).Label).(groupType)))
        sortMenu.Children(i).Enable = 'on';
      else
        sortMenu.Children(i).Enable = 'off';
      end
    else
      sortMenu.Children(i).Checked = 'on';
    end
  end
end