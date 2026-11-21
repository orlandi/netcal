%--------------------------------------------------------------------------
function selectionMenu = redoSelectionMenu(experiment, parent)
  [groupType, idx] = getCurrentGroup();
  
  delete(parent.selection.root);
  selectionMenu = generateSelectionMenu(experiment, parent.root);
  selectGroup([], [], groupType, idx);
end
