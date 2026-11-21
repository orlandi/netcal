function menuProjectRename(~, ~, appName)
  netcalMainWindow = gcbf;
  project = getappdata(netcalMainWindow, 'project');
  answer = inputdlg('Enter the new project name',...
                    'Project rename', [1 60], {project.name});
  if(isempty(answer))
      return;
  end
  answer{1} = strtrim(answer{1});
  logMsg(['Renaming project file from ' project.name '.proj to ' answer{:} '.proj'], 'w');

  oldProjectFile = [project.folder project.name '.proj'];
  project.name = answer{:};
  newProjectFile = [project.folder project.name '.proj'];
  % Move the .proj file
  try
    movefile(oldProjectFile, newProjectFile);
  catch ME
    logMsg('Moving failed', 'e');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e'); %#ok<SPRINTFN>
    return;
  end
  netcalMainWindow.Name = [appName, ' - ' project.name];
	setappdata(netcalMainWindow, 'project', project);
end