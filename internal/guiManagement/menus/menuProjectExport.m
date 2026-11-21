function menuProjectExport(~, ~)
  netcalMainWindow = gcbf;
  project = getappdata(netcalMainWindow, 'project');
  
  defOptions = exportProjectOptions;
  defOptions.exportFolder = project.folder;
  defOptions.newProjectName = [project.name '_exported'];
  [success, projectExportOptionsCurrent] = preloadOptions([], defOptions, gcbf, true, false);
  if(~success)
    return;
  end
  
  if(~projectExportOptionsCurrent.exportFolder | ~exist(projectExportOptionsCurrent.exportFolder, 'dir')) %#ok<BDSCI,OR2,BDLGI>
    logMsg('Invalid export folder. Are you sure the folder exists?', 'e');
    return;
  end
  fileList = rdir([projectExportOptionsCurrent.exportFolder filesep, '**']);
  if(~isempty(fileList))
    choice = questdlg(sprintf('Found: %d files in the export directory. It should be empty. Do you want to continue?', length(fileList)), ...
    'Export project', ...
    'Yes', 'No', 'Cancel', 'Cancel');

    switch choice
      case 'Yes'
      case 'No'
        return;
      case 'Cancel'
        return;
    end
  end
  
  onlyChecked = projectExportOptionsCurrent.exportOnlyCheckedExperiments;
  project = getappdata(netcalMainWindow, 'project');
  bigFields = getBigFields();
  validFields = [];
  validFieldsText = {};
  validFieldsSize = [];
  fileList = {};
  fileListFolder = {}; % For compatibility before matlab 2016b
  ncbar.automatic('Checking for existing files');
  if(onlyChecked)
    validExperiments = find(project.checkedExperiments);
  else
    validExperiments = 1:length(project.checkedExperiments);
  end
  for it1 = 1:length(bigFields)
    curField = bigFields{it1};
    extension = '.DAT';
    fileList{it1} = [];
    fileListFolder{it1} = {};
    for it2 = 1:length(validExperiments)
      newFile = dir([project.folder, project.experiments{validExperiments(it2)}, filesep, 'data', filesep, project.experiments{validExperiments(it2)}, '_', curField, lower(extension)]);
      if(~isempty(newFile))
        fileList{it1} = [fileList{it1}; newFile];
        fileListFolder{it1}{end+1} = [project.folder, project.experiments{validExperiments(it2)}, filesep, 'data', filesep];
      end
    end
    curSize = 0;
    if(numel(fileList{it1}) == 0)
      continue;
    end
    for it2 = 1:length(fileList{it1})
      curSize = curSize+fileList{it1}(it2).bytes;
    end
    if(curSize/1e6 > 1e3)
      curSizeText = sprintf('%s: %.2f GB', curField, curSize/1e9);
    else
      curSizeText = sprintf('%s: %.2f MB', curField, curSize/1e6);
    end
    validFields  = [validFields; it1];
    validFieldsText{end+1} = curSizeText;
    validFieldsSize = [validFieldsSize; curSize];
  end
  fileList = fileList(validFields);
  fileListFolder = fileListFolder(validFields);
  extension = '.EXP';
  fileListExp = [];
  fileListExpFolder = {};
  sizeExp = 0;
  for it2 = 1:length(validExperiments)
    %fileList{it1} = [fileList{it1}; rdir([project.folder, project.experiments{validExperiments(it2)}, filesep, '**', filesep, '*.*'], ['regexp(upper(name), ''.*\' upper(curField) extension '$'')'])];
    newFile = dir([project.folderFiles, project.experiments{validExperiments(it2)}, lower(extension)]);
    if(~isempty(newFile))
      fileListExp = [fileListExp; newFile];
      fileListExpFolder{end+1} = project.folderFiles;
      sizeExp = sizeExp +fileListExp(it2).bytes;
    end
  end
  %fileListExp = rdir([project.folder, '**', filesep, '*.*'], ['regexp(upper(name), ''.*\' extension '$'')']);
 
  ncbar.close();
  
  if(~isempty(validFieldsText))
    [fieldsToExport, success] = listdlg('PromptString', 'Select additional data files to export', 'SelectionMode', 'multiple', 'ListString', validFieldsText, 'ListSize', [500 300]);
    if(~success)
      fieldsToExport = [];
    end
    fullFileList = fileListExp;
    fullFileListFolder = fileListExpFolder;
    totalSize = sizeExp;
    for it1 = 1:numel(fieldsToExport)
      curList = fileList{fieldsToExport(it1)};
      curListFolder = fileListFolder{fieldsToExport(it1)};
      fullFileList = [fullFileList; curList];
      fullFileListFolder = [fullFileListFolder, curListFolder];
      totalSize = totalSize + validFieldsSize(fieldsToExport(it1));
    end
  else
    totalSize = sizeExp;
    fullFileList = fileListExp;
    fullFileListFolder = fileListExpFolder;
  end
  logMsg(sprintf('We will be exporting %d files with a total size of %.3f GB\n', length(fullFileList), totalSize/1e9));

  % Need to redo:
  % checkedExperiments
  % experiments
  % labels
  % name
  % folder
  % folderFiles
  newProject = project;
  newProject.checkedExperiments = newProject.checkedExperiments(validExperiments);
  newProject.experiments = newProject.experiments(validExperiments);
  newProject.labels = newProject.labels(validExperiments);
  newProject.name = projectExportOptionsCurrent.newProjectName;
  newProject.folder = fullfile([projectExportOptionsCurrent.exportFolder filesep]);
  newProject.folderFiles = [newProject.folder 'projectFiles' filesep];
  if(~exist(newProject.folderFiles, 'dir'))
    mkdir(newProject.folderFiles);
  end
  % Let's copy all the files first
  curFolder = project.folder;
  newFolder = newProject.folder;
  ncbar.automatic(sprintf('Copying files to the new folder (%d/%d)', 0, length(fullFileList)));
  for it1 = 1:length(fullFileList)
    %oldFile = [fullFileList(it1).folder filesep fullFileList(it1).name];
    oldFile = [fullFileListFolder{it1} filesep fullFileList(it1).name];
    newFile = strrep(oldFile, curFolder, newFolder);
    %fprintf('%s to %s\n', oldFile, newFile);
    % Create the new folder
    [fpa, ~, ~] = fileparts(newFile);
    if(~exist(fpa, 'dir'))
      mkdir(fpa);
    end
    % Now copy the files
    [success, msg, msgID] = copyfile(oldFile, newFile, 'f');
    if(~success)
      logMsg(sprintf('Something went wrong copy file %s to %s. Msg: %s', oldFile, newFile, msg), 'e');
      return;
    end
    ncbar.setCurrentBarName(sprintf('Copying files to the new folder (%d/%d)', it1, length(fullFileList)));
  end
  ncbar.close();
  saveProject(newProject);
  if(projectExportOptionsCurrent.createZip)
    ncbar.automatic('Creating zip file');
    warning('off','MATLAB:zip:archiveName');
    zip([newProject.folder newProject.name '_export'], newProject.folder);
    warning('on','MATLAB:zip:archiveName');
    ncbar.close();
  end
  project.projectExportOptionsCurrent = projectExportOptionsCurrent;
  setappdata(netcalMainWindow, 'project', project);
  setappdata(netcalMainWindow, 'projectExportOptionsCurrent', projectExportOptionsCurrent);
  logMsg('Project succesfully exported');
end