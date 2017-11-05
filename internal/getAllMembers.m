function members = getAllMembers(experiment, mainGroup)
  members = [];
  % Get ALL subgroups in case of parents
  if(strcmpi(mainGroup, 'all'))
    groupList = getExperimentGroupsNames(experiment);
  else
    groupList = getExperimentGroupsNames(experiment, mainGroup);
  end

  % Empty check
  if(isempty(groupList))
    logMsg(sprintf('Group %s not found on experiment %s', mainGroup, experiment.name), 'w');
    return;
  end

  % Time to iterate through all the groups
  for git = 1:length(groupList)
    if(strcmpi(groupList{git}, 'none'))
      newMembers = 1:length(experiment.ROI);
    else
      [newMembers, ~, ~] = getExperimentGroupMembers(experiment, groupList{git});
    end
    members = [members; newMembers(:)];
  end
  members = unique(members);
end