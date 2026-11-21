function netcal(varargin)
% NETCAL Network Calcium analysis
%
% USAGE:
%    netcal
%
% INPUT arguments:
%    none
%
% OUTPUT arguments:
%    none
%
% EXAMPLE:
%    netcal
%
% Copyright (C) 2016-2025, Javier G. Orlandi <javier.orlandi@ucalgary.ca>

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>
%#ok<*SPRINTFN>

%% Initialization (1)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
appName = 'NETCAL';

if(nargin > 0 && islogical(varargin{1}))
  DEVELOPMENT = varargin{1};
else
  DEVELOPMENT = false;
end

guiImprovements = true;

if(~DEVELOPMENT)
  appName = [appName, ' pre-release'];
else
  appName = [appName, ' Dev Build'];
end
  
currVersion = '10.0.1';
appFolder = fileparts(mfilename('fullpath'));

if(~DEVELOPMENT)
  updaterSource = strrep(fileread(fullfile(appFolder, 'internal', 'guiManagement', 'updatePath.txt')), sprintf('\n'), '');
else
  try
    updaterSource = strrep(fileread(fullfile(appFolder, 'development', 'guiManagement', 'updatePath.txt')), sprintf('\n'), '');
  catch
    updaterSource = strrep(fileread(fullfile(appFolder, 'internal', 'guiManagement', 'updatePath.txt')), sprintf('\n'), '');
  end
end

recentProjectsList = {};
activeNode = [];
projectTree = [];
experimentSelectionMode = 'single'; % Single / multiple / pipeline

warning('off', 'MATLAB:dispatcher:nameConflict');
warning('off', 'MATLAB:Java:DuplicateClass');
warning('off', 'MATLAB:load:variableNotFound');
warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved');
warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved');
warning('off', 'MATLAB:class:PropUsingAtSyntax');
warning('off', 'MATLAB:deprecated:FunctionWithDeprecatedSyntax');
warning('off', 'export_fig:exportgraphics');

%%% Java includes
javaaddpath({fullfile(appFolder, 'internal', 'java'), ...
             fullfile(appFolder, 'external', 'guiManagement', 'dndcontrol'), ...
             fullfile(appFolder, 'external', 'guiManagement', 'JavaTreeWrapper', '+uiextras', '+jTree', 'UIExtrasTree.jar')});

import('uiextras.jTree.*');

addpath(genpath(appFolder));
rmpath(genpath([appFolder filesep '.git'])) % But exclude .git/
rmpath(genpath([appFolder filesep 'old'])) % And old
rmpath(genpath([appFolder filesep 'external' filesep 'cvx'])) % And CVX for now
rmpath(genpath(fullfile(appFolder, 'external', 'guiManagement', 'JavaTreeWrapper', 'java_src'))); % And tree wrapper sources
subFolderList = dir(appFolder);
for i = 1:length(subFolderList)
  if(subFolderList(i).isdir && any(strfind(subFolderList(i).name, 'netcal')))
    rmpath(genpath([appFolder filesep subFolderList(i).name])) % And any subfolders containing netcal
  end
end

warning('on', 'MATLAB:dispatcher:nameConflict');
warning('on', 'MATLAB:Java:DuplicateClass');
openFiguresList = [];
updateTimer = [];
updateIsRunning = false;

%% Splash screen
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
splash = splashScreen();

%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'none',...
                       'Tag','netcalMainWindow', ...
                       'DockControls','off',...
                       'NumberTitle', 'off',...
                       'ResizeFcn', @resizeCallback, ...
                       'WindowKeyPressFcn', @keyPressCallback, ...
                       'MenuBar', 'none',...
                       'Name', [appName ' v' currVersion],...
                       'Position', [100 100 900 700],...
                       'CloseRequestFcn', @closeCallback);
% Leave it like this for possible incompatibilities
netcalMainWindow = hs.mainWindow;
netcalMainWindow.Position = setFigurePosition(gcbf, 'width', 900, 'height', 700, 'centered', true);

netcalOptionsCurrent = [];
try
  loadOptions();
catch
end
getappdata(netcalMainWindow, 'netcalOptionsCurrent');
try
  headerFontSize = netcalOptionsCurrent.headerFontSize;
  textFontSize = netcalOptionsCurrent.mainFontSize;
  uiFontSize = netcalOptionsCurrent.uiFontSize;
  treeFontSize = netcalOptionsCurrent.treeFontSize;
  %baseTreeFont = java.awt.Font('Helvetica', java.awt.Font.PLAIN, treeFontSize);  % font name, style, size
  %baseTreeFont = java.awt.Font('Monospaced', java.awt.Font.PLAIN, treeFontSize);  % font name, style, size
  baseTreeFont = java.awt.Font('Courier', java.awt.Font.PLAIN, treeFontSize);  % font name, style, size
catch
end

try
  %hs.mainWindowTabInfoVbox = uix.VBox('Parent', netcalMainWindow);
  hs.mainWindowVbox = uix.VBox('Parent', netcalMainWindow);
catch
  errMsg = {'GUI Layout Toolbox missing. Please install it from the installDependencies folder'};
  uiwait(msgbox(errMsg,'Error','warn'));
  close(hs.mainWindow);
  return;
end
hs.expButtonsBox = uix.HButtonBox('Parent', hs.mainWindowVbox);
hs.expButtonsBoxSingle = uicontrol('Parent', hs.expButtonsBox, 'Style', 'togglebutton', 'String', 'Single experiment analysis', 'FontSize', textFontSize, 'Callback', {@experimentMode, 'single'});
hs.expButtonsBoxSingle.Value = 1;
hs.expButtonsBoxMultiple = uicontrol('Parent', hs.expButtonsBox, 'Style', 'togglebutton', 'String', 'Batch mode', 'FontSize', textFontSize, 'Callback', {@experimentMode, 'multiple'});
hs.expButtonsBoxPipeline = uicontrol('Parent', hs.expButtonsBox, 'Style', 'togglebutton', 'String', 'Pipeline', 'FontSize', textFontSize, 'Callback', {@experimentMode, 'pipeline'});

set(hs.expButtonsBox, 'ButtonSize', [250 35], 'Spacing', 25);

hs.expCardPanel = uix.CardPanel('Parent', hs.mainWindowVbox);

%%% Now the single panel
hs.singleExperimentPanelHBox = uix.HBox('Parent', hs.expCardPanel);

hs.singleExperimentPanel = uix.Panel('Parent', hs.singleExperimentPanelHBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Experiment list', 'Hittest', 'off');
  
% Prepare the info editbox
hs.infoPanelParent = uix.Panel('Parent', hs.singleExperimentPanelHBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Experiment Information');

hs.infoPanel = uicontrol('Parent', hs.infoPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background', 'w');

set(hs.singleExperimentPanelHBox, 'Widths', [-1 -1], 'Spacing', 10, 'Padding', 5);

%%% Now the multiple panel
hs.multipleExperimentPanelHBox = uix.HBox('Parent', hs.expCardPanel);

hs.multipleExperimentPanel = uix.Panel('Parent', hs.multipleExperimentPanelHBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Experiment list', 'ButtonDownFcn', @testCallback);

% Prepare the info editbox
hs.multipleInfoPanelParent = uix.Panel('Parent', hs.multipleExperimentPanelHBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Project Information');

% hs.multipleInfoPanel = uicontrol('Parent', hs.multipleInfoPanelParent, ...
%                       'style', 'edit', 'max', 5, 'Background', 'w');

set(hs.multipleExperimentPanelHBox, 'Widths', [-1 -1], 'Spacing', 10, 'Padding', 5);

%%% Now the pipeline panel
% The big 4 panels
hs.pipelineExperimentPanelHBox = uix.HBox('Parent', hs.expCardPanel);
% Experiment list panel - first the VBox
hs.pipelineExperimentVBox = uix.VBox('Parent', hs.pipelineExperimentPanelHBox);
% Now the actual experiment list
hs.pipelineExperimentPanel = uix.Panel('Parent', hs.pipelineExperimentVBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Experiment list');
% Now the info panel
hs.pipelineExperimentPanelInfoParent = uix.Panel('Parent', hs.pipelineExperimentVBox, ...
                                                 'BorderType', 'none', 'FontSize', headerFontSize,...
                                                 'Title', 'Project Information');

set(hs.pipelineExperimentVBox, 'Heights', [-1 125]);

% Now the function list                             
hs.pipelineFunctionListVBox = uix.VBox('Parent', hs.pipelineExperimentPanelHBox, 'Visible', 'on');
hs.pipelineFunctionListPanel = uix.Panel('Parent', hs.pipelineFunctionListVBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Available functions');
hs.pipelineFunctionListInfoPanelParent = uix.Panel('Parent', hs.pipelineFunctionListVBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Description');
hs.pipelineFunctionListInfoPanel = uicontrol('Parent', hs.pipelineFunctionListInfoPanelParent, ...
                               'style', 'edit', 'max', 5, 'Background', 'w');
set(hs.pipelineFunctionListVBox, 'Heights', [-1 125]);

% Actual pipeline function panel with all its buttons
hs.pipelinePanelVBox = uix.VBox('Parent', hs.pipelineExperimentPanelHBox, 'Visible', 'on');
hs.pipelinePanel = uix.Panel('Parent', hs.pipelinePanelVBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Pipeline');
hs.pipelinePanelButtons = uix.HBox('Parent', hs.pipelinePanelVBox);
uix.Empty('Parent', hs.pipelinePanelButtons);
hs.pipelinePanelButtonsRun = uicontrol('Parent', hs.pipelinePanelButtons, 'Style', 'pushbutton', 'String', 'Run', 'FontSize', textFontSize, 'Callback', @pipelineRun);
hs.pipelinePanelButtonsCheck = uicontrol('Parent', hs.pipelinePanelButtons, 'Style', 'pushbutton', 'String', 'Check', 'FontSize', textFontSize, 'Callback', @pipelineCheck);
uix.Empty('Parent', hs.pipelinePanelButtons);
     
set(hs.pipelinePanelButtons, 'Widths', [-1 80 80 -1], 'Spacing', 5, 'Padding', 5);

set(hs.pipelinePanelVBox, 'Heights', [-1 35]);

hs.pipelineOptionsPanel = uix.Panel('Parent', hs.pipelineExperimentPanelHBox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Options');

set(hs.pipelineExperimentPanelHBox, 'Widths', [-1 -1 -1 -1], 'Spacing', 10, 'Padding', 5);

% Prepare the pipeline panels
pipelineTree = [];
pipelineTreeListener = [];
pipelineFunctionsTree = [];


hs.expCardPanel.Selection = 1;
% Prepare the single experiment panel
projectTree = [];
% Prepare the multiple experiment panel
projectTreeContextMenu = uicontextmenu('Parent', netcalMainWindow);
projectTreeContextMenuRoot = uicontextmenu('Parent', netcalMainWindow);

  
% Prepare the log editbox
hs.logPanelParent = uix.Panel('Parent', hs.mainWindowVbox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Message log');
hs.logPanel = uicontrol('Parent', hs.logPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background','w');

set(hs.mainWindowVbox, 'Heights', [40 -7 -4], 'Spacing', 25, 'Padding', 15);

setappdata(netcalMainWindow, 'hs', hs);
if(guiImprovements)
  netcalMainWindow.WindowButtonMotionFcn = @testHack;
end
%addlistener(netcalMainWindow, 'KeyPress', @testHack);
%% Declare menus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

hs.menu = initializeMenu();

%% Initialization (2)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Diable menus visibility
menuHandles = findall(netcalMainWindow, 'type', 'uimenu');
for i = 1:numel(menuHandles)
  menuHandles(i).HandleVisibility = 'off';
end

% Get the underlying Java editbox, which is contained within a scroll-panel
% For all editable panels
% Original names
%nameList = {'logPanel', 'infoPanel', 'multipleInfoPanel', 'pipelineExperimentPanelInfo'};
nameList = {'logPanel', 'infoPanel'};
nameListBoxTag = 'EditBox';
for it = 1:length(nameList)
  jScrollPanel = findjobj(hs.(nameList{it}));
  try
    jScrollPanel.setVerticalScrollBarPolicy(jScrollPanel.java.VERTICAL_SCROLLBAR_AS_NEEDED);
    jScrollPanel = jScrollPanel.getViewport;
  catch
    % may possibly already be the viewport, depending on release/platform etc.
  end
  try
    hs.([nameList{it}, nameListBoxTag]) = handle(jScrollPanel.getView,'CallbackProperties');
    hs.([nameList{it}, nameListBoxTag]).setEditable(false);
  catch
  end
end

% The other editable panels
curPanel = findjobj(hs.pipelineFunctionListInfoPanel);
try
  curPanel.setVerticalScrollBarPolicy(curPanel.java.VERTICAL_SCROLLBAR_AS_NEEDED);
  curPanel = curPanel.getViewport;
catch
  % may possibly already be the viewport, depending on release/platform etc.
end
try
  hs.pipelineFunctionListInfoPanelEditBox = handle(curPanel.getView,'CallbackProperties');
  hs.pipelineFunctionListInfoPanelEditBox.setEditable(false);
catch
end
logMessage(hs.pipelineFunctionListInfoPanelEditBox, 'No Function selected');

% Set initial log messages
logMessage(hs.infoPanelEditBox, 'No active project', 'w');
logMessage(hs.infoPanelEditBox, '', 'w');
logMessage(hs.infoPanelEditBox, 'Please load a project or create a new one to get started', 'w');
logMessage(hs.infoPanelEditBox, '', 'w');
logMessage(hs.infoPanelEditBox, 'You can also drag and drop a recording to automatically create a new project', 'w');

logMessage(hs.logPanelEditBox, [appName ' v' currVersion]);

% Set the log message handle as app data
setappdata(netcalMainWindow, 'logHandle', hs.logPanelEditBox);
setappdata(netcalMainWindow, 'infoHandle', hs.infoPanelEditBox);

setappdata(netcalMainWindow, 'experimentSelectionMode', experimentSelectionMode);
resizeHandle = netcalMainWindow.ResizeFcn;
setappdata(netcalMainWindow, 'ResizeHandle', resizeHandle);

try
  createPipelineFunctions();
catch ME
  logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
end


netcalMainWindow.Visible = 'on';
updateMenu();
try
  resetProjectTree();
catch ME
  logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
end

try
  loadPipeline([], [], [appFolder filesep 'pipeline.json']);
catch ME
  logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
end
pause(1);
delete(splash);
needsUpdating = updateChecker();
if(needsUpdating)
  return;
end
hs.menu = pluginChecker(appFolder, hs.menu);
hs.menu = docChecker(appFolder, hs.menu);
optionsChecker();
%releaseNotesChecker();

%diary on;

%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  function testHack(hObject, eData)
    %hObject
    %eData
  %  ar = hittest(hObject);
    %ar == hs.pipelinePanel
    %ar.Children
    %ar
    %findjobj(ar)
    %3
  end
%--------------------------------------------------------------------------
function closeCallback(hObject, ~, ~)
  project = getappdata(netcalMainWindow, 'project');
  if(~isempty(project))
    choice = questdlg('Do you want to save the project?', ...
    'Quit', ...
    'Yes', 'No', 'Cancel', 'Cancel');

    switch choice
      case 'Yes'
        if(~isempty(updateTimer))
          try
            stop(updateTimer);
            delete(updateTimer);
          catch
          end
        end
        menuProjectSave(hObject);
        saveOptions();
        if(~isempty(projectTree))
          if(isprop(projectTree, 'Root') && ~isempty(projectTree.Root))
            delete(projectTree.Root)
          end
          delete(projectTree)
        end
        delete(netcalMainWindow);
      case 'No'
        saveOptions();
        if(~isempty(projectTree))
          if(isprop(projectTree, 'Root') && ~isempty(projectTree.Root))
            delete(projectTree.Root)
          end
          delete(projectTree)
        end
        delete(netcalMainWindow);
      case 'Cancel'
        return;
    end
  else
    if(~isempty(updateTimer))
      try
        stop(updateTimer);
        delete(updateTimer);
      catch
      end
    end
    saveOptions();
    if(~isempty(projectTree))
      if(isprop(projectTree, 'Root') && ~isempty(projectTree.Root))
        delete(projectTree.Root)
      end
      delete(projectTree)
    end
    delete(netcalMainWindow);
  end
end

%--------------------------------------------------------------------------
function menuProjectNew(~, ~, varargin)
  
  if(nargin > 2)
    nProject = newProject(varargin{:});
  else
    nProject = newProject();
  end

  if(~isempty(nProject))
    project = nProject;
    % If the project is valid, clear app data
    clearAppData(netcalMainWindow);
    setappdata(netcalMainWindow, 'project', project);

    netcalMainWindow.Name = [appName, ' - ' project.name];
    try
      updateMenu();
    catch ME
      logMsg('Something went wrong updating the menu tree', 'w');
    end
    resetProjectTree();
    menuProjectSave();

    % Add this project to the recent projects lists
    fullProjFile = fullfile(project.folder, [project.name '.proj']);
    repeatedRecentProject = false;
    for it = 1:length(recentProjectsList)
      if(strcmpi(fullProjFile, recentProjectsList{it}))
        repeatedRecentProject = true;
        % Swap the orders so it this one becomes the last one
        recentProjectsList{end+1} = fullProjFile;
        recentProjectsList(it) = [];
        break;
      end
    end
    if(~repeatedRecentProject)
      netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
      recentProjectsList{end+1} = fullProjFile;
      if(length(recentProjectsList) > netcalOptionsCurrent.numberRecentProjects)
        recentProjectsList(1) = [];
      end
    end
  end
end

%--------------------------------------------------------------------------
function menuProjectLoad(hObject, ~, recentProject)

if(nargin < 3)
  recentProject = [];
end
  % Do a dryRun to check if the project can be loaded
  netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
  if(isempty(recentProject))
    nProject = loadProject('dryRun', true, 'defaultFolder', netcalOptionsCurrent.defaultFolder, 'gui', netcalMainWindow);
  else
    [fpa, fpb, fpc] = fileparts(recentProject);
    nProject = loadProject('dryRun', true, ...
      'folder', [fpa filesep], 'name', fpb, 'gui', netcalMainWindow);
  end
  % If so, delete everything and continue
  if(~isempty(nProject))
    % Check to save current project
    project = getappdata(netcalMainWindow, 'project');
    if(~isempty(project))
      choice = questdlg('Do you want to save the current project?', ...
      'Load Project', ...
      'Yes', 'No', 'Cancel', 'Cancel');

      switch choice
        case 'Yes'
          menuProjectSave(hObject);
        case 'No'
        case 'Cancel'
          return;
      end
    end

    clearAppData(netcalMainWindow);
    nProject = loadProject('folder', nProject.folder, 'name', nProject.name, 'gui', netcalMainWindow);
    
    ncbar.automatic('Please wait...');
    project = nProject;
    setappdata(netcalMainWindow, 'project', project);

    netcalMainWindow.Name = [appName, ' - ' project.name];

    % Add this project to the recent projects lists
    fullProjFile = fullfile(project.folder, [project.name '.proj']);
    repeatedRecentProject = false;
    for it = 1:length(recentProjectsList)
      if(strcmpi(fullProjFile, recentProjectsList{it}))
        repeatedRecentProject = true;
        % Swap the orders so it this one becomes the last one
        recentProjectsList{end+1} = fullProjFile;
        recentProjectsList(it) = [];
        break;
      end
    end
    if(~repeatedRecentProject)
      recentProjectsList{end+1} = fullProjFile;
      if(length(recentProjectsList) > netcalOptionsCurrent.numberRecentProjects)
        recentProjectsList(1) = [];
      end
    end
    % Load the project pipeline
    try
      loadPipeline([], [], [project.folder filesep 'pipeline.json']);
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
    updateMenu();
    try
      resetProjectTree();
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
    end
    printProjectInfo(project);
    if(~isempty(projectTree.Root.Children))
      projectTree.SelectedNodes = projectTree.Root.Children(1);
      printSavedExperimentInfo();
    end
    ncbar.close();
  end
end

function checkedHack(hObject, ~)
  if(guiImprovements)
    if(isa(hObject, 'experimentTree'))
      project = getappdata(netcalMainWindow, 'project');
      if(isempty(project))
        return;
      end
      prevChecked = project.checkedExperiments;
      project.checkedExperiments = arrayfun(@(x)x.Checked, hObject.Root.Children);
      for it = 1:length(hObject.Root.Children)
        hObject.Root.Children(it).UserData{3} = logical(project.checkedExperiments(it));
      end
      %hObject.Root.Children(5).UserData
      %arrayfun(@(x)x.Checked, hObject.Root.Children)
      % Only update screen if there is a change
      if(any(prevChecked ~= project.checkedExperiments))
        printProjectInfo(project);
        setappdata(netcalMainWindow, 'project', project);
      end
    elseif(isa(hObject, 'CheckboxTreePipeline'))
      % Here do nothing, because we do not care
    end
  end
end

%--------------------------------------------------------------------------
function experimentMode(hObject, ~, type)
  %tic
  % If it is already the right one, do nothing and leave the button selected
  if(strcmpi(experimentSelectionMode, type))
    hObject.Value = 1;
    return;
  end
  switch type
    case 'single'
      experimentSelectionMode = type;
      hs.expCardPanel.Selection = 1;
      hs.expButtonsBoxSingle.Value = 1;
      hs.expButtonsBoxMultiple.Value = 0;
      hs.expButtonsBoxPipeline.Value = 0;
      hs.infoPanel.Parent = hs.infoPanelParent;
    case 'multiple'
      if(checkOpenFigures() > 0)
        logMsg('Cannot change to multiple experiment mode while active experiment windows are still open', 'w');
        hs.expCardPanel.Selection = 1;
        hs.expButtonsBoxSingle.Value = 1;
        hs.expButtonsBoxMultiple.Value = 0;
        experimentSelectionMode = 'single';
        setappdata(netcalMainWindow, 'experimentSelectionMode', experimentSelectionMode);
        return;
      end
      experimentSelectionMode = type;

      hs.expCardPanel.Selection = 2;
      hs.expButtonsBoxSingle.Value = 0;
      hs.expButtonsBoxMultiple.Value = 1;
      hs.expButtonsBoxPipeline.Value = 0;
      hs.infoPanel.Parent = hs.multipleInfoPanelParent;
    case 'pipeline'
      if(checkOpenFigures() > 0)
        logMsg('Cannot change to pipeline experiment mode while active experiment windows are still open', 'w');
        hs.expCardPanel.Selection = 1;
        hs.expButtonsBoxSingle.Value = 1;
        hs.expButtonsBoxMultiple.Value = 0;
        hs.expButtonsBoxPipeline.Value = 0;
        experimentSelectionMode = 'single';
        setappdata(netcalMainWindow, 'experimentSelectionMode', experimentSelectionMode);
        return;
      end
      experimentSelectionMode = type;

      hs.expCardPanel.Selection = 3;
      hs.expButtonsBoxSingle.Value = 0;
      hs.expButtonsBoxMultiple.Value = 0;
      hs.expButtonsBoxPipeline.Value = 1;
      hs.infoPanel.Parent = hs.pipelineExperimentPanelInfoParent;
  end
  % Reset infoPanel viewport
  jScrollPanel = findjobj(hs.infoPanel);
  try
    jScrollPanel.setVerticalScrollBarPolicy(jScrollPanel.java.VERTICAL_SCROLLBAR_AS_NEEDED);
    jScrollPanel = jScrollPanel.getViewport;
  catch
    % may possibly already be the viewport, depending on release/platform etc.
  end
  hs.infoPanelEditBox = handle(jScrollPanel.getView,'CallbackProperties');
  hs.infoPanelEditBox.setEditable(false);
  setappdata(netcalMainWindow, 'infoHandle', hs.infoPanelEditBox);
  
  switch type
    case 'single'
      printSavedExperimentInfo();
  end
  
  updateMenu();
  
  try
    updateProjectTree();
  catch ME
    logMsg('There was some issue updating the project tree', 'w');
  end
  
  setappdata(netcalMainWindow, 'experimentSelectionMode', experimentSelectionMode);
end

%--------------------------------------------------------------------------
function menuExperimentAdd(~, ~, varargin)
  project = getappdata(netcalMainWindow, 'project');
  if(nargin < 3)
    [newExperiment, project] = loadExperiment('project', project);
  else
    [newExperiment, project] = loadExperiment(varargin{:}, 'project', project);
  end
  setappdata(netcalMainWindow, 'project', project);
  if(isempty(newExperiment))
    return;
  end
  % Ask for the experiment name
  answer = inputdlg('Experiment name',...
                    'Experiment name', [1 60], {newExperiment.name});
  if(~isempty(answer))
    answer{1} = strtrim(answer{1});
    newExperiment.name = answer{:};
  else
    logMsg('Invalid experiment name', 'e');
    return;
  end

  if(~isempty(newExperiment))
    % First pass to check if the experiment name has already been used
    for it = 1:size(project.experiments,2)
      if(strcmpi(project.experiments{it}, newExperiment.name))
        answer = inputdlg('New experiment name',...
                          'Duplicate experiment name', [1 60], {newExperiment.name});
        if(~isempty(answer))
          newExperiment.name = answer{:};
          logMsg(sprintf('Experiment name changed to: %s', newExperiment.name));
        end
      end
    end
    % Second pass to check that now it is ok. If not, abort
    for it = 1:size(project.experiments,2)
      if(strcmpi(project.experiments{it}, newExperiment.name) || isempty(newExperiment.name))
        logMsg('Invalid experiment name', 'e');
        return;
      end
    end
    % Change the folder to match the project structure
    newExperiment.folder = [project.folder newExperiment.name filesep];
    newExperiment.saveFile = ['..' filesep 'projectFiles' filesep newExperiment.name '.exp'];
    
    project = addNewExperimentNode(newExperiment, project);
    
    saveExperiment(newExperiment, 'verbose', true);
    netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
    if(netcalOptionsCurrent.automaticallySaveProject)
      saveProject(project, 'verbose', true, 'gui', netcalMainWindow);
    end
    setappdata(netcalMainWindow, 'project', project);
    projectTree.SelectedNodes = projectTree.Root.Children(end);
    printSavedExperimentInfo();
    updateMenu();
    updateProjectTree();
    
  end
end

%--------------------------------------------------------------------------
function menuExperimentAddSilent(varargin)
  project = getappdata(netcalMainWindow, 'project');
  [newExperiment, project] = loadExperiment(varargin{:}, 'verbose', false, 'pbar', 0, 'project', project);
  setappdata(netcalMainWindow, 'project', project);
  
  if(isempty(newExperiment))
    return;
  end
  if(any(strcmp(project.experiments, newExperiment.name)))
    logMsg('An experiment with this name already exists. Add through the menus instead', netcalMainWindow, 'e');
    return;
  end
  % Change the folder to match the project structure
  newExperiment.folder = [project.folder newExperiment.name filesep];
  newExperiment.saveFile = ['..' filesep 'projectFiles' filesep newExperiment.name '.exp'];

  project = addNewExperimentNode(newExperiment, project);

  saveExperiment(newExperiment, 'verbose', false, 'pbar', 0);
  netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
  if(netcalOptionsCurrent.automaticallySaveProject)
    saveProject(project, 'verbose', false, 'gui', netcalMainWindow);
  end
  setappdata(netcalMainWindow, 'project', project);
  projectTree.SelectedNodes = projectTree.Root.Children(end);
  printSavedExperimentInfo();
  updateMenu();
  updateProjectTree();
end

%--------------------------------------------------------------------------
function menuExperimentAddBatch(~, ~, ~)

  project = getappdata(netcalMainWindow, 'project');
  defOptions = addBatchOptions;
  defOptions.rootFolder = project.folder;
  [success, addBatchOptionsCurrent] = preloadOptions([], defOptions, gcbf, true, false);
  if(~success)
    return;
  end
  switch addBatchOptionsCurrent.extension
    case 'Hamamatsu HIS files (*.HIS)'
      extension = '.HIS';
      filterIndex = 2;
    case 'Hamamatsu DCIMG files (*.DCIMG)'
      extension = '.DCIMG';
      filterIndex = 3;
    case 'AVI files (*.AVI)'
      extension = '.AVI';
      filterIndex = 4;
    case 'NETCAL experiment (*.EXP)'
      extension = '.EXP';
      filterIndex = 6;
    case 'NETCAL binary experiment (*.BIN)'
      extension = '.BIN';
      filterIndex = 7;
    case 'quick_dev (*.MAT)'
      extension = '.MAT';
      filterIndex = 8;
    case 'CRCNS datasets (*.MAT)'
      extension = '.MAT';
      filterIndex = 9;
    case 'Big TIFF files (*.BTF)'
      extension = '.BTF';
      filterIndex = 10;
    case 'track2p datasets (*.MAT)'
      extension = '.MAT';
      filterIndex = 13;
    otherwise
      filterIndex = 1;
  end
  
  if(~addBatchOptionsCurrent.rootFolder | ~exist(addBatchOptionsCurrent.rootFolder, 'dir')) %#ok<BDSCI,OR2,BDLGI>
    logMsg('Invalid root folder', 'e');
    return;
  end
  fileList = rdir([[addBatchOptionsCurrent.rootFolder filesep], '**', filesep, '*.*'], ['regexp(upper(name), ''.*\' extension '$'')']);
  if(isempty(fileList))
    logMsg('No files found', 'e');
    return;
  end
  names = cell(length(fileList), 1);
  for i = 1:length(fileList)
    names{i} = fileList(i).name;
  end
  [filesToImport, success] = listdlg('PromptString', 'Select files to import', 'SelectionMode', 'multiple', 'ListString', names, 'ListSize', [500 300]);
  if(~success)
    return;
  end
  ncbar('Importing experiments', '');
  for i = 1:length(filesToImport)
    experimentFile = names{filesToImport(i)};
    try
      [newExperiment, project] = loadExperiment(experimentFile, 'verbose', false, 'filterIndex', filterIndex, 'pbar', 2, 'project', project);
    catch ME 
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
      logMsg(sprintf('Something went wrong importing experiment %s', experimentFile), 'e');
      continue;
    end
    if(isempty(newExperiment))
      logMsg(['Something went wrong loading ' experimentFile], 'e');
      continue;
    end
    newExperiment.name = [newExperiment.name addBatchOptionsCurrent.appendToName];
    % Ask for the experiment name
    if(~addBatchOptionsCurrent.acceptDefaultNames)
      answer = inputdlg('Experiment name',...
                        'Experiment name', [1 60], {newExperiment.name});
      if(~isempty(answer))
        answer{1} = strtrim(answer{1});
        newExperiment.name = answer{:};
      else
        logMsg('Invalid experiment name', 'e');
        continue;
      end
    end
    
    if(~isempty(newExperiment))
      validName = true;
      % First pass to check if the experiment name has already been used
      for it = 1:size(project.experiments,2)
        if(strcmpi(project.experiments{it}, newExperiment.name))
          if(addBatchOptionsCurrent.skipRepeatedNames)
            logMsg(sprintf('Skipping repeated experiment with name %s', newExperiment.name));
            validName = false;
            break;
          end
          answer = inputdlg('New experiment name',...
                            'Duplicate experiment name', [1 60], {newExperiment.name});
          if(~isempty(answer))
            newExperiment.name = answer{:};
            logMsg(sprintf('Experiment name changed to: %s', newExperiment.name));
          end
        end
      end
      % Second pass to check that now it is ok. If not, abort
      if(validName)
        for it = 1:size(project.experiments,2)
          if(strcmpi(project.experiments{it}, newExperiment.name) || isempty(newExperiment.name))
            logMsg('Invalid experiment name', 'e');
            validName = false;
            break;
          end
        end
      end
      if(~validName)
        continue;
      end
      % Change the folder to match the project structure
      newExperiment.folder = [project.folder newExperiment.name filesep];
      newExperiment.saveFile = ['..' filesep 'projectFiles' filesep newExperiment.name '.exp'];
      
      project = addNewExperimentNode(newExperiment, project, [], addBatchOptionsCurrent.tag);
      setappdata(netcalMainWindow, 'project', project);
      if(~isempty(newExperiment))
        saveExperiment(newExperiment, 'verbose', true, 'pbar', 2);
      end
    end
    ncbar.update(i/length(filesToImport), 1);
  end
  ncbar.close();
  updateMenu();
  updateProjectTree();
  project.addBatchOptionsCurrent = addBatchOptionsCurrent;
  netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
  if(netcalOptionsCurrent.automaticallySaveProject)
    saveProject(project, 'verbose', true, 'gui', netcalMainWindow);
  end
  setappdata(netcalMainWindow, 'project', project);
  setappdata(netcalMainWindow, 'addBatchOptionsCurrent', addBatchOptionsCurrent);
  projectTree.SelectedNodes = projectTree.Root.Children(end);
  printSavedExperimentInfo();
end

%--------------------------------------------------------------------------
function keyPressCallback(hObject, eventData)

  switch eventData.Key
    case '1'
      if(strcmp(eventData.Modifier, 'control'))
        experimentMode([], [], 'single');
      end
    case '2'
      if(strcmp(eventData.Modifier, 'control'))
        experimentMode([], [], 'multiple');
      end
    case '3'
      if(strcmp(eventData.Modifier, 'control'))
        experimentMode([], [], 'pipeline');
      end
  end
end

%--------------------------------------------------------------------------
function resizeCallback(hObject, ~, varargin)
  if(~isempty(varargin) && strcmp(varargin{1}, 'full'))
    updateMenu();
    resetProjectTree();
  elseif(~isempty(varargin) && strcmp(varargin{1}, 'resetTree'))
    updateMenu();
    resetProjectTree();
  elseif(isempty(hObject))
    updateMenu();
  end
end

%--------------------------------------------------------------------------
function menuExperimentChangeFPS(~, ~)
  project = getappdata(netcalMainWindow, 'project');
  switch experimentSelectionMode % Single / multiple / pipeline
    case 'single'
      experiment = loadCurrentExperiment(project, 'pbar', 0);
      answer = inputdlg('Enter the new framerate (fps)',...
                          'FPS change', [1 60], {num2str(experiment.fps)});
      if(isempty(answer))
          return;
      end
      answer{1} = str2double(strtrim(answer{1}));
      logMsg(sprintf('FPS changed from %.2f to %.2f', experiment.fps, answer{1}), 'w');
      logMsg('You will need to reanalyze anything involving times other than the raw traces', 'w');
      oldfps = experiment.fps;
      experiment.fps = answer{1};
      experiment.totalTime = experiment.numFrames/experiment.fps;
      if(isfield(experiment, 't'))
        experiment.t = experiment.t*oldfps/experiment.fps;
      end
      if(isfield(experiment, 'rawT'))
        experiment.rawT = experiment.rawT*oldfps/experiment.fps;
      end

      saveExperiment(experiment, 'verbose', true);
    otherwise
      checkedExperiments = find(project.checkedExperiments);
      newFPS = [];
      ncbar('Changing FPS', '');
      for it = 1:length(checkedExperiments)
        ncbar.setActiveBar(1);
        ncbar.update(it/length(checkedExperiments));
        experimentName = project.experiments{checkedExperiments(it)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = loadExperiment(experimentFile, 'project', project, 'pbar', 2);
        if(it == 1)
          answer = inputdlg(sprintf('You are about to change the frame rate of %d experiments. Enter the new framerate (fps)', length(checkedExperiments)),...
                           'FPS change', [1 60], {num2str(experiment.fps)});
          if(isempty(answer))
            ncbar.close();
            return;
          end
          newFPS = str2double(strtrim(answer{1}));        
        end
        oldfps = experiment.fps;
        experiment.fps = newFPS;
        experiment.totalTime = experiment.numFrames/experiment.fps;
        if(isfield(experiment, 't'))
          experiment.t = experiment.t*oldfps/experiment.fps;
        end
        if(isfield(experiment, 'rawT'))
          experiment.rawT = experiment.rawT*oldfps/experiment.fps;
        end
        saveExperiment(experiment, 'verbose', true, 'pbar', 2);
      end
      ncbar.close();
      logMsg(sprintf('FPS changed to %.2f', newFPS), 'w');
      logMsg('You will need to reanalyze anything involving times other than the raw traces', 'w');
  end
  updateMenu();
  updateProjectTree();
  printSavedExperimentInfo();
end

%--------------------------------------------------------------------------
function menuExperimentChangeHandle(~, ~)
  project = getappdata(netcalMainWindow, 'project');
  switch experimentSelectionMode % Single / multiple / pipeline
    case 'single'
      experiment = loadCurrentExperiment(project, 'pbar', 0);

      formatsList = {'*.HIS;*.DCIMG;*.AVI;*.BIN;*.BTF;*.MJ2;*.TIF;*.TIFF', 'All Movie files (*.HIS, *.DCIMG, *.AVI, *.BIN, *.BTF, *.MJ2, *.TIF, *.TIFF)';...
               '*.HIS', 'Hamamatsu HIS files (*.HIS)';...
               '*.DCIMG', 'Hamamatsu DCIMG files (*.DCIMG)'; ...
               '*.AVI', 'AVI files (*.AVI)';...
               '*.BTF', 'Big TIFF files (*.BTF)';...
               '*.TIF;*.TIFF', 'TIF sequence/multitif (*.TIF,*.TIFF)';...
               '*.EXP', 'NETCAL experiment (*.EXP)'; ...
               '*.BIN', 'NETCAL binary experiment (*.BIN)'; ...
               '*.MAT', 'quick_dev (*.MAT)'; ...
               '*.MAT', 'CRCNS datasets (*.MAT)'; ...
               '*.MAT', 'RIKEN (*.MAT)'; ...
               '*.MJ2', 'Motion JPEG 2000'};
      [fileName, pathName, filterIndex] = uigetfile(formatsList,'Select new movie file', experiment.folder);
      fileName = [pathName fileName];
      if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
        return;
      end
      logMsg(sprintf('Experiment handle changed from %s to %s', experiment.handle, fileName), 'w');
      experiment.handle = fileName;
      logMsg('You will need to reanalyze everything', 'w');
      saveExperiment(experiment, 'verbose', true);
      updateMenu();
      updateProjectTree();
      printSavedExperimentInfo();
    otherwise
      checkedExperiments = find(project.checkedExperiments);
      for it = 1:length(checkedExperiments)
        experimentName = project.experiments{checkedExperiments(it)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = loadExperiment(experimentFile, 'project', project, 'verbose', true);
        formatsList = {'*.HIS;*.DCIMG;*.AVI;*.BIN;*.BTF;*.MJ2;*.TIF;*.TIFF', 'All Movie files (*.HIS, *.DCIMG, *.AVI, *.BIN, *.BTF, *.MJ2, *.TIF, *.TIFF)';...
               '*.HIS', 'Hamamatsu HIS files (*.HIS)';...
               '*.DCIMG', 'Hamamatsu DCIMG files (*.DCIMG)'; ...
               '*.AVI', 'AVI files (*.AVI)';...
               '*.BTF', 'Big TIFF files (*.BTF)';...
               '*.TIF;*.TIFF', 'TIF sequence/multitif (*.TIF,*.TIFF)';...
               '*.EXP', 'NETCAL experiment (*.EXP)'; ...
               '*.BIN', 'NETCAL binary experiment (*.BIN)'; ...
               '*.MAT', 'quick_dev (*.MAT)'; ...
               '*.MAT', 'CRCNS datasets (*.MAT)'; ...
               '*.MAT', 'RIKEN (*.MAT)'; ...
               '*.MJ2', 'Motion JPEG 2000'};
        [fileName, pathName, filterIndex] = uigetfile(formatsList,'Select new movie file', experiment.folder);
        fileName = [pathName fileName];
        if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
          return;
        end
        logMsg(sprintf('Experiment handle changed from %s to %s', experiment.handle, fileName), 'w');
        experiment.handle = fileName;
        logMsg('You will need to reanalyze everything', 'w');
        saveExperiment(experiment, 'verbose', true);
        updateMenu();
        updateProjectTree();
        printSavedExperimentInfo();
      end
  end
end

%--------------------------------------------------------------------------
function menuExperimentChangeNumFrames(~, ~)
  project = getappdata(netcalMainWindow, 'project');
  switch experimentSelectionMode % Single / multiple / pipeline
    case 'single'
      experiment = loadCurrentExperiment(project, 'pbar', 0);
      answer = inputdlg('Enter the new number of frames',...
                          'numFrames change', [1 60], {num2str(experiment.numFrames)});
      if(isempty(answer))
          return;
      end
      answer{1} = str2double(strtrim(answer{1}));
      logMsg(sprintf('numFrames changed from %d to %d', experiment.numFrames, answer{1}), 'w');
      experiment.numFrames = answer{1};
      experiment.totalTime = experiment.numFrames/experiment.fps;
      saveExperiment(experiment, 'verbose', true);
      
    otherwise
      checkedExperiments = find(project.checkedExperiments);
      newNumFrames = [];
      ncbar('Changing number of frames', '');
      for it = 1:length(checkedExperiments)
        ncbar.setActiveBar(1);
        ncbar.update(it/length(checkedExperiments));
        experimentName = project.experiments{checkedExperiments(it)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = loadExperiment(experimentFile, 'project', project, 'pbar', 2);
        if(it == 1)
          answer = inputdlg(sprintf('You are about to change the number of frames of %d experiments. Enter the new number of frames', length(checkedExperiments)),...
                           'Number of frames change', [1 60], {num2str(experiment.numFrames)});
          if(isempty(answer))
            ncbar.close();
            return;
          end
          newNumFrames = str2double(strtrim(answer{1}));
        end
        oldNumFrames = experiment.numFrames;
        experiment.numFrames = newNumFrames;
        experiment.totalTime = experiment.numFrames/experiment.fps;
        saveExperiment(experiment, 'verbose', true, 'pbar', 2);
      end
      ncbar.close();
      logMsg(sprintf('numFrames changed from %d to %d', oldNumFrames,  experiment.numFrames), 'w');
  end
  updateMenu();
  updateProjectTree();
  printSavedExperimentInfo();
end

%--------------------------------------------------------------------------
function menuExperimentForceHISprecaching(~, ~, mode)
  project = getappdata(netcalMainWindow, 'project');
  experiment = loadCurrentExperiment(project, 'pbar', 0);
  
  switch mode
    case 'fast'
      answer = inputdlg('Select base frameJump (default 512)',...
                      'frameJump', [1 60], {'512'});
      if(isempty(answer))
        return;
      end
      answer{1} = str2double(strtrim(answer{1}));             
      [experiment, success] = precacheHISframes(experiment, 'mode', 'fast', 'force', true, 'frameJump', answer{1});
      if(~success)
        logMsg('Something went wrong while precaching', 'e');
        return;
      end
    case 'normal'
      [experiment, success] = precacheHISframes(experiment, 'mode', 'normal', 'force', true);
      if(~success)
        logMsg('Something went wrong while precaching', 'e');
        return;
      end
  end
  saveExperiment(experiment, 'verbose', true);
  updateMenu();
  updateProjectTree();
  printSavedExperimentInfo();
end


%--------------------------------------------------------------------------
function menuExperimentRestoreBackup(~, ~)
  project = getappdata(netcalMainWindow, 'project');
  experimentName = project.experiments{project.currentExperiment};
  experimentFile = [project.folderFiles experimentName '.exp'];
  experimentBackupFile = [project.folderFiles experimentName '.bak'];
  experimentHourlyBackupFile = [project.folderFiles experimentName '.bkh'];
  
  choice = questdlg(sprintf('Are you sure you want to restore the backup of experiment %s ? Last changes will be lost', experimentName), ...
                    'Restore experiment backup', ...
                    'Restore previous backup', 'Restore hourly backup', 'Cancel', 'Cancel');
  switch choice
      case 'Restore previous backup'
      if(exist(experimentBackupFile, 'file') ~= 2)
        logMsg('No backup found', 'w');
        return;
      end
      copyfile(experimentBackupFile, experimentFile);
      logMsg(sprintf('Previous backup restored for experiment %s', experimentName));
      case 'Restore hourly backup'
      if(exist(experimentHourlyBackupFile, 'file') ~= 2)
        logMsg('No backup found', 'w');
        return;
      end
      copyfile(experimentHourlyBackupFile, experimentFile);
      logMsg(sprintf('Hourly backup restored for experiment %s', experimentName));
      case 'Cancel'
          return;
  end
  updateMenu();
  updateProjectTree();
  printSavedExperimentInfo();
end

%--------------------------------------------------------------------------
function menuExperimentGlobalAnalysis(hObject, ~, analysisFunction, optionsClass, varargin)

  project = getappdata(netcalMainWindow, 'project');
  if(~isempty(varargin) && strcmp(varargin{1}, 'population'))
    populationSelection = true;
    varargin = varargin(2:end);
  else
    populationSelection = false;
  end
  if(~isempty(varargin) && strcmp(varargin{1}, 'project'))
    passProject = true;
    varargin = varargin(2:end);
  else
    passProject = false;
  end
  if(~isempty(varargin) && length(varargin) > 1 && strcmp(varargin{2}, 'noChanges'))
    allowOptionsChanges = false;
    varargin = varargin(3:end);
  else
    allowOptionsChanges = true;
  end
  
  switch experimentSelectionMode
    case 'single'
      if(isempty(project.currentExperiment))
        logMsg('No experiment selected','e');
        return;
      end
      % Load the experiment
      experiment = loadCurrentExperiment(project, 'pbar', 0);
      if(passProject)
          proj = project;
          proj.checkedExperiments = strcmp(project.experiments, experiment.name);
      end
      if(~isempty(optionsClass))
        % Define the options
        if(passProject)
          [success, optionsClassCurrent] = preloadOptions(experiment, optionsClass, netcalMainWindow, allowOptionsChanges, false, proj);
        else
          [success, optionsClassCurrent] = preloadOptions(experiment, optionsClass, netcalMainWindow, allowOptionsChanges, false);
        end
        if(success)
          if(isprop(optionsClassCurrent, 'pipelineMode'))
            switch optionsClassCurrent.pipelineMode
              case 'experiment'
              case 'project'
                logMsg('"pipelineMode: project" can only be selected on batch mode or pipeline', 'e');
                return;
            end
          end  
          if(populationSelection)
            groupNames = getExperimentGroupsNames(experiment);
            % Select the population
            [selectedPopulations, success] = listdlg('PromptString', 'Select groups', 'SelectionMode', 'multiple', 'ListString', groupNames);
            if(~success)
              return;
            end
            selectedPopulations = groupNames(selectedPopulations);
            subset = [];
            % This assumes that it can process all elements of different pops at once, i.e., each analysis on a given element is independent on the rest of the population
            for k = 1:length(selectedPopulations)
              subset = [subset; getExperimentGroupMembers(experiment, selectedPopulations{k})];
            end
            % Just in case
            subset = unique(subset);
            if(passProject)
              project = analysisFunction(project, optionsClassCurrent, 'subset', subset, varargin{:});
            else
              experiment = analysisFunction(experiment, optionsClassCurrent, 'subset', subset, varargin{:});
            end
          else
            % Do the analysis
            if(passProject)
              varargin{:}
              proj = analysisFunction(proj, optionsClassCurrent, varargin{:});
            else
              experiment = analysisFunction(experiment, optionsClassCurrent, varargin{:});
            end
          end
          % Save the options
          if(passProject)
            project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
          else
            experiment.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
            project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
            %setappdata(netcalMainWindow, [class(optionsClassCurrent) 'Current'], optionsClassCurrent);
            saveExperiment(experiment, 'verbose', false);
          end
        end
      else
        if(passProject)
          proj = analysisFunction(proj, varargin{:});
        else
          experiment = analysisFunction(experiment, varargin{:});
          saveExperiment(experiment, 'verbose', false);
        end
      end
    case 'multiple'
      checkedExperiments = find(project.checkedExperiments);
      if(sum(checkedExperiments) == 0)
        logMsg('No checked experiments found', 'e');
        return;
      end
      runMode = 'experiment';
      if(passProject)
        runMode = 'project';
      end
      % Define the options
      if(~isempty(optionsClass))
        % Load using the first checked exp
        experimentName = project.experiments{checkedExperiments(1)};
        exp = [project.folderFiles experimentName '.exp'];
        if(passProject)
          [success, optionsClassCurrent] = preloadOptions(exp, optionsClass, netcalMainWindow, allowOptionsChanges, false, project);
        else
          [success, optionsClassCurrent] = preloadOptions(exp, optionsClass, netcalMainWindow, allowOptionsChanges, false);
        end
        if(~success)
          return;
        end
        if(isprop(optionsClassCurrent, 'pipelineMode'))
          switch optionsClassCurrent.pipelineMode
            case 'experiment'
              runMode = 'experiment';
            case 'project'
              runMode = 'project';
          end
        end
      end
      
      if(populationSelection)
        % Preload the groups from the first experiment and select the appropiate one
        experimentName = project.experiments{checkedExperiments(1)};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experiment = load(experimentFile, '-mat', 'traceGroups', 'traceGroupsNames');
        groupNames = getExperimentGroupsNames(experiment);
        % Select the population
        [selectedPopulations, success] = listdlg('PromptString', 'Select groups', 'SelectionMode', 'multiple', 'ListString', groupNames);
        if(~success)
          return;
        end
        selectedPopulations = groupNames(selectedPopulations);
      end
      % Iterate through the experiments
      switch runMode
        case 'experiment'
          logMsgHeader(sprintf('Running %s on %d experiments', hObject.Label, sum(project.checkedExperiments)), 'start');
          % Define the progress bar
          ncbar('Processing experiments', '');
          p = 2;
          ncbar.setSequentialBar(false);
          for it = 1:length(checkedExperiments)
            % Load the experiment
            experimentName = project.experiments{checkedExperiments(it)};
            experimentFile = [project.folderFiles experimentName '.exp'];
            ncbar.setCurrentBar(1);
            ncbar.setCurrentBarName(sprintf('Processing: %s (%d/%d)', experimentName, it, length(checkedExperiments)));
            ncbar.update((it-1)/length(checkedExperiments), 1, 'force');
            ncbar.increaseCurrentBar();

            ncbar.setCurrentBarName('Loading experiment...');
            [experiment, project] = loadExperiment(experimentFile, 'verbose', false, 'project', project, 'pbar', p);

            if(isempty(experiment))
                logMsg(['Something went wrong loading experiment ' experimentName], 'e');
                continue;
            end
            % Do the analysis
            if(~isempty(optionsClass))
              if(populationSelection)
                subset = [];
                % This assumes that it can process all elements of different pops at once, i.e., each analysis on a given element is independent on the rest of the population
                for k = 1:length(selectedPopulations)
                  subset = [subset; getExperimentGroupMembers(experiment, selectedPopulations{k})];
                end
                try
                  experiment = analysisFunction(experiment, optionsClassCurrent, 'subset', subset, 'pbar', p, varargin{:});
                catch ME
                  logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
                  logMsg(sprintf('Something went wrong when performing on experiment %s', experiment.name), 'e');
                end
              else
                try
                  experiment = analysisFunction(experiment, optionsClassCurrent, 'pbar', p, varargin{:});
                catch ME
                  logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
                  logMsg(sprintf('Something went wrong when performing on experiment %s', experiment.name), 'e');
                end
              end
              experiment.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
              project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
            else
              if(populationSelection)
                subset = [];
                % This assumes that it can process all elements of different pops at once, i.e., each analysis on a given element is independent on the rest of the population
                for k = 1:length(selectedPopulations)
                  subset = [subset; getExperimentGroupMembers(experiment, selectedPopulations{k})];
                end
                try
                  experiment = analysisFunction(experiment, 'subset', subset, 'pbar', p, varargin{:});
                catch ME
                  logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
                  logMsg(sprintf('Something went wrong when performing on experiment %s', experiment.name), 'e');
                end
              else
                try
                  experiment = analysisFunction(experiment, 'pbar', p, varargin{:});
                catch ME
                  logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
                  logMsg(sprintf('Something went wrong when performing on experiment %s', experiment.name), 'e');
                end
              end
            end
            ncbar.setCurrentBarName('Saving experiment...');
            saveExperiment(experiment, 'verbose', false, 'pbar', p);
            ncbar.update(it/length(checkedExperiments), 1, 'force');
          end
        case 'project'
          try
            project = analysisFunction(project, optionsClassCurrent, varargin{:});
          catch ME
            logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
          end
      end
      if(~isempty(optionsClass))
        project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
      end
      updateProjectTree();
      ncbar.close();
      logMsgHeader('Done!', 'finish');
  end
  printSavedExperimentInfo();
  setappdata(netcalMainWindow, 'project', project);
  updateMenu();
end

%--------------------------------------------------------------------------
function menuNewGuiWindow(~, ~, windowFunction)
  project = getappdata(netcalMainWindow, 'project');
  if(isempty(project.currentExperiment))
    logMsg('No experiment selected','e');
    return;
  end
  ncbar.automatic('Loading experiment');
  experiment = loadCurrentExperiment(project, 'pbar', 0);
  ncbar.close();
  if(checkOpenFigures() > 0)
    logMsg('Another figure that might modify the active experiment is already open. Changes will not be saved by default', 'w');
    experiment.virtual = true;
  else
    if(isfield(experiment, 'virtual'))
      experiment = rmfield(experiment, 'virtual');
    end
  end
  addFigure(windowFunction(experiment));
end

%--------------------------------------------------------------------------
function menuNewProjectGuiWindow(~, ~, windowFunction)
  project = getappdata(netcalMainWindow, 'project');
  
  if(checkOpenFigures() > 0)
    logMsg('Another figure that might modify the active experiment is already open. Be careful', 'w');
  end
  addFigure(windowFunction(project));
end





%--------------------------------------------------------------------------
function success = menuExperimentDelete(hObject, ~, ~)
  success = false;
  experimentName = removeLabel(hObject.Label);
  choice = questdlg(sprintf('Are you sure you want to delete experiment %s ?', experimentName), ...
                            'Delete experiment', ...
                            'Yes', 'No', 'Cancel', 'Cancel');

  switch choice
    case 'Yes'
      % Continue (ugh)
    case 'No'
      return;
    case 'Cancel'
      return;
  end

  %hObject.Label
  project = getappdata(netcalMainWindow, 'project');

  logMsgHeader(sprintf('Deleting experiment: %s', experimentName), 'start', netcalMainWindow);
  experimentFile = [project.folderFiles experimentName '.exp'];  
  project = removeExperimentNode(experimentName, project);

  try
    delete(experimentFile);
  catch ME
    logMsg('Delete warning', 'w');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
  end
  % Also delete all files
  try
    rmdir([project.folder experimentName], 's');
  catch ME
    logMsg('Delete warning', 'w');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
  end

  setappdata(netcalMainWindow, 'project', project);

  logMsgHeader('Done!', 'finish', netcalMainWindow);
  updateMenu();
  updateProjectTree();
  success = true;
end

%--------------------------------------------------------------------------
function success = menuExperimentRename(experiment)
  success = false;
  if(~isempty(experiment))
    oldName = experiment.name;
    project = getappdata(netcalMainWindow, 'project');
    experimentID = getExperimentID(project, experiment.name);
    oldSaveFile = [project.folderFiles experiment.name '.exp'];
    answer = inputdlg('New experiment name',...
                      'Rename experiment', [1 60], {experiment.name});

    % Pass to check that the name is ok
    for it = 1:size(project.experiments,2)
        if(isempty(answer) || strcmpi(project.experiments{it}, answer))
            logMsg('Invalid experiment name', 'e');
            return;
        end
    end
    answer{1} = strtrim(answer{1});
    experiment.name = answer{:};
    logMsg(sprintf('Experiment renamed to: %s', experiment.name));
    project.experiments{experimentID} = experiment.name;
    % Now change the node
    projectTree.Root.Children(experimentID).UserData{1} = experiment.name;
    projectTree.Root.Children(experimentID).TooltipString = experiment.name;
    fullName = [experiment.name ' (' project.labels{experimentID} ')'];
    projectTree.Root.Children(experimentID).Name = sprintf('%3.d. %s', experimentID, fullName);
                                                     
    % Change the folder to match the project structure
    oldFolder = experiment.folder;
    
    experiment.folder = [project.folder experiment.name filesep];
    experiment.saveFile = ['..' filesep 'projectFiles' filesep experiment.name '.exp'];
    % Move all project files
    try
      movefile(oldFolder, experiment.folder, 'f');
    catch ME
      logMsg('Copying failed', 'e');
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
      if(~exist(experiment.folder, 'dir'))
        mkdir(experiment.folder);
      end
    end
    % Rename all files
    fileList = rdir([experiment.folder , '**', filesep, '**']);
    for it = 1:length(fileList)
      fileList(it)
      if(exist(fileList(it).name, 'file') & ~exist(fileList(it).name, 'dir') & strfind(fileList(it).name, oldName))
        [fpa, fpb, fpc ] = fileparts(fileList(it).name);
        nfpb = strrep(fpb, oldName, experiment.name);
        if(~strcmp(fpb, nfpb))
          newName = [fpa filesep nfpb fpc];
          movefile(fileList(it).name, newName, 'f');
        end
      end
    end
    % Now change the name of all possible strings that we do not have
    % changed already
    skipFields = {'name', 'folder', 'saveFile', 'handle'};
    experiment = updateNames(experiment, oldName, experiment.name, skipFields);
    try
      delete(oldSaveFile);
    catch ME
      logMsg('Delete failed', 'e');
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
    % Save the experiment
    saveExperiment(experiment, 'verbose', true);
    setappdata(netcalMainWindow, 'project', project);

    updateMenu();
    updateProjectTree();
    success = true;
  end
end

%--------------------------------------------------------------------------
function success = menuExperimentDuplicate(experiment)
  success = false;
  
  if(~isempty(experiment))
    project = getappdata(netcalMainWindow, 'project');
    answer = inputdlg('New experiment name',...
                      'Duplicate experiment name', [1 60], {experiment.name});

    % Pass to check that the name is ok
    for it = 1:size(project.experiments,2)
      if(isempty(answer) || strcmpi(project.experiments{it}, answer))
        logMsg('Invalid experiment name', 'e');
        return;
      end
    end
    answer{1} = strtrim(answer{1});
    oldName = experiment.name;
    % Save current experiment before the switch
    if(nargin < 3)
      experiment = saveExperiment(experiment, 'verbose', true);
    end
    % load traces again
    experiment.name = answer{:};
    
    
    % Change the folder to match the project structure
    oldFolder = experiment.folder;
    experiment.folder = [project.folder experiment.name filesep];
    experiment.saveFile = ['..' filesep 'projectFiles' filesep experiment.name '.exp'];
    ncbar.automatic('Copying files');
    % Copy all project files
    copyfile(oldFolder, experiment.folder, 'f');
    % Rename all files
    fileList = rdir([experiment.folder , '**', filesep, '**']);

    for it = 1:length(fileList)
      if(exist(fileList(it).name, 'file') & ~exist(fileList(it).name, 'dir') & strfind(fileList(it).name, oldName))
        [fpa, fpb, fpc ] = fileparts(fileList(it).name);
        nfpb = strrep(fpb, oldName, experiment.name);
        if(~strcmp(fpb, nfpb))
          newName = [fpa filesep nfpb fpc];
          movefile(fileList(it).name, newName, 'f');
        end
      end
    end
    % Now change the name of all possible strings that we do not have
    % changed already
    skipFields = {'name', 'folder', 'saveFile', 'handle'};
    experiment = updateNames(experiment, oldName, experiment.name, skipFields);
    logMsg(sprintf('Experiment duplicated with new name: %s', experiment.name));
    experiment = saveExperiment(experiment, 'verbose', true);
    
    % Here is where we add it to the project list and create the new node
    project = addNewExperimentNode(experiment, project, oldName);
    
    setappdata(netcalMainWindow, 'project', project);
    ncbar.close();
    updateMenu();
    updateProjectTree();
    success = true;
  end
end

%--------------------------------------------------------------------------
function menuExperimentImport(~, ~)
  project = getappdata(netcalMainWindow, 'project');
  formatsList = {'*.PROJ', 'NETCAL project (*.PROJ)';...
                 '*.EXP', 'NETCAL experiment (*.EXP)'};
  [fileName, pathName] = uigetfile(formatsList, 'Select file', project.folder, 'MultiSelect', 'on');


  if(isa(fileName, 'cell'))
      for it = 1:length(fileName)
          fileNameSingle = [pathName fileName{it}];
          [~, ~, ext] = fileparts(fileNameSingle);
          if(strcmpi(ext,'.exp'))
              if(it == 1)
                  importExperiment(fileNameSingle, true);
              else
                  importExperiment(fileNameSingle, false);
              end
          elseif(strcmpi(ext, '.proj'))
              importProject(fileNameSingle);
          else
              logMsg('Invlaid extension','e');
          end
      end
  else
      if(fileName == 0 | ~exist([pathName fileName], 'file'))
          logMsg('Invalid file', 'e');
          return;
      end
      fileName = [pathName fileName];
      [~, ~, ext] = fileparts(fileName);
      if(strcmpi(ext,'.exp'))
          importExperiment(fileName);
      elseif(strcmpi(ext, '.proj'))
          importProject(fileName);
      else
          logMsg('Invlaid extension', 'e');
      end
  end
  updateMenu();
  updateProjectTree();
end

%--------------------------------------------------------------------------
function importProject(fileName)
  %stateVariables = who('-file', fileName);
  [newProjectFolder, ~, ~] = fileparts(fileName);
  project = [];
  project = load(fileName, '-mat');
  if(isempty(project) || isempty(project.experiments))
    logMsg('Invalid project', 'e');
    return;
  end
  importedProject = project;
  % Update the project folder just in case
  importedProject.folder = [newProjectFolder filesep];
  % Dialog with experiments to select
  experimentNames = importedProject.experiments;
  for it = 1:length(experimentNames)
    if(isfield(importedProject, 'labels') && length(importedProject.labels) >= it && ~isempty(importedProject.labels{it}))
      experimentNames{it} = [importedProject.experiments{it} ' (' importedProject.labels{it} ')'];
    else
      experimentNames{it} = importedProject.experiments{it};
    end
  end
  [selection, ok] = listdlg('PromptString', 'Select experiments to import', 'ListString', experimentNames, 'SelectionMode', 'multiple');
  if(~ok)
    return;
  end
  logMsg(sprintf('Importing %d experiments from project: %s', length(selection), importedProject.name));
  answer = inputdlg('Do you want to append some text to the experiment names? (leave blank otherwise)',...
                    'Append experiment names', [1 60], {''});
  if(isempty(answer{1}))
    appendText = '';
  else
    appendText = strtrim(answer{1});
  end

  % Save the current project before actually adding anything
  project = getappdata(netcalMainWindow, 'project');
  saveProject(project);
  setappdata(netcalMainWindow, 'project', project);

  % Now just loop through the experiments and import then one by one
  ncbar('Importing experiments');
  newExperimentIndex = zeros(size(selection));
  for itt = 1:length(selection)
    experimentName = importedProject.experiments{selection(itt)};
    if(itt == 1)
      success = importExperiment([importedProject.folder 'projectFiles' filesep experimentName '.exp'], true, appendText); % Only save old experiment in the first iteration
    else
      success = importExperiment([importedProject.folder 'projectFiles' filesep experimentName '.exp'], false, appendText);
    end
    if(~success)
      logMsg(sprintf('Something went wrong while importing experiment: %s', experimentName), 'e');
      ncbar.close();
      return;
    end
    newExperimentIndex(itt) = success;

    ncbar.update(itt/length(selection));
  end
  ncbar.close();

  project = getappdata(netcalMainWindow, 'project');
  % Now it's time to play with the labels
  choice = questdlg('What do you want to do with the labels from the imported experiments?', ...
                    'Import labels', ...
                    'Also import', 'Use a new one', 'Skip', 'Also import');
  % Handle response
  switch choice
    case 'Also import'
      for itt = 1:length(selection)
        if(isfield(importedProject, 'labels') && length(importedProject.labels) >= selection(itt) && ~isempty(importedProject.labels{selection(itt)}))
          project.labels{newExperimentIndex(itt)} = importedProject.labels{selection(itt)};
          fullName = [project.experiments{newExperimentIndex(itt)} ' (' project.labels{newExperimentIndex(itt)} ')'];
          projectTree.Root.Children(newExperimentIndex(itt)).UserData{2} = project.labels{newExperimentIndex(itt)};
          projectTree.Root.Children(newExperimentIndex(itt)).Name = sprintf('%3.d. %s', newExperimentIndex(itt), fullName);
        end
      end
    case 'Use a new one'
      answer = inputdlg('New label (for all imported experiments)',...
                        'New label', [1 60], {'WT'});
      if(isempty(answer))
        answer{1} = '';
      end
      answer{1} = strtrim(answer{1});
      for itt = 1:length(selection)
        project.labels{newExperimentIndex(itt)} = answer{1};
        fullName = [project.experiments{newExperimentIndex(itt)} ' (' project.labels{newExperimentIndex(itt)} ')'];
        projectTree.Root.Children(newExperimentIndex(itt)).UserData{2} = project.labels{newExperimentIndex(itt)};
        projectTree.Root.Children(newExperimentIndex(itt)).Name = sprintf('%3.d. %s', newExperimentIndex(itt), fullName);
      end
    case 'Skip'
  end

  setappdata(netcalMainWindow, 'project', project);
  updateMenu();
  updateProjectTree();
end

%--------------------------------------------------------------------------
function success = importExperiment(fileName, varargin)
    % Varargin 1: save oldExperiment true/false true by default
    % Varargin 2: text to append to the experiment name (before any checks)
    % Success returns the index in the project of the new experiment
    renamedExperiment = false;
    if(length(varargin) >= 2)
      appendText = varargin{2};
      renamedExperiment = true;
    else
      appendText = '';
    end
    project = getappdata(netcalMainWindow, 'project');
    success = 0;
    [newExperiment, project] = loadExperiment(fileName, 'verbose', false, 'project', project, 'import', true);
    newExperimentOriginalName = newExperiment.name;
    newExperiment.name = [newExperiment.name appendText];
    
    if(~isempty(newExperiment))
      % First pass to check if the experiment name has already been used
      for it = 1:size(project.experiments,2)
        if(strcmpi(project.experiments{it}, newExperiment.name))
          answer = inputdlg('New experiment name',...
                            'Duplicate experiment name', [1 60], {newExperiment.name});
          answer{1} = strtrim(answer{1});
          newExperiment.name = answer{:};
          logMsg(sprintf('Experiment name changed to: %s', newExperiment.name));
          renamedExperiment = true;
        end
      end
      % Second pass to check that now it is ok. If not, abort
      for it = 1:size(project.experiments,2)
        if(strcmpi(project.experiments{it}, newExperiment.name) || isempty(newExperiment.name))
          logMsg('Invalid experiment name', 'e');
          return;
        end
      end

      % Now we do the change
      experiment = newExperiment;

      % Change the folder to match the project structure
      %oldFolder = experiment.folder; % This only work if the experiment is in the right folder
      [oldFolder, ~, ~] = fileparts(fileName);
      oldFolder = [oldFolder filesep '..' filesep newExperimentOriginalName filesep];
      experiment.folder = [project.folder experiment.name filesep];
      experiment.saveFile = ['..' filesep 'projectFiles' filesep experiment.name '.exp'];
      % Copy all project files
      try
        copyfile(oldFolder, experiment.folder, 'f');
      catch ME
        logMsg('Error copying the file...', 'w');
        logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
      end
      
      project = addNewExperimentNode(experiment, project);
      
      % If renamed (from a duplicate) we need to update file names
      if(renamedExperiment)
        oldName = newExperimentOriginalName;
        fileList = rdir([experiment.folder , '**', filesep, '**']);
        for it = 1:length(fileList)
          if(exist(fileList(it).name, 'file') & ~exist(fileList(it).name, 'dir') & strfind(fileList(it).name, oldName))
            [fpa, fpb, fpc ] = fileparts(fileList(it).name);
            nfpb = strrep(fpb, oldName, experiment.name);
            if(~strcmp(fpb, nfpb))
              newName = [fpa filesep nfpb fpc];
              movefile(fileList(it).name, newName, 'f');
            end
          end
        end
        experiment = updateNames(experiment, oldName, experiment.name);
      end
      
      saveExperiment(experiment, 'verbose', false, 'pbar', 0);
      netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
      if(netcalOptionsCurrent.automaticallySaveProject)
        saveProject(project, 'verbose', false, 'gui', netcalMainWindow);
      end
      setappdata(netcalMainWindow, 'project', project);
      updateMenu();
      updateProjectTree();
    else
      logMsg('Invalid experiment file', 'e');
    end
    success = length(project.experiments);
end

%--------------------------------------------------------------------------
function success = menuExperimentAssignLabel(nodeList, type, label)

  project = getappdata(netcalMainWindow, 'project');
  %[labelList, uniqueLabels, labelsCombinations, labelsCombinationsNames, experimentsPerCombinedLabel] = getLabelList(project, varargin)
% Cell list, with {1x2} cells with contents experiment ID (absolute) and
% label
  for it = 1:length(nodeList)
    curExperiment = nodeList(it).UserData{1};
    curExperimentIdx = find(strcmp(project.experiments, curExperiment));
    switch type
      case 'assign'
        newLabelList = label;
      case 'add'
        newLabelList = strtrim(strsplit(label, ','));
        try
          oldLabelList = strtrim(strsplit(project.labels{curExperimentIdx}, ','));
        catch
          oldLabelList = '';
        end
        newLabelList = strjoin(unique([newLabelList oldLabelList]), ', ');
      case 'remove'
        newLabelList = strtrim(strsplit(label, ','));
        try
          oldLabelList = strtrim(strsplit(project.labels{curExperimentIdx}, ','));
        catch
          oldLabelList = '';
        end
        newLabelList = strjoin(setdiff(oldLabelList, newLabelList), ', ');
        if(isempty(newLabelList))
          newLabelList = '';
        end
    end
    nodeList(it).UserData{2} = newLabelList;
    project.labels{curExperimentIdx} = newLabelList;
    nodeList(it).Name = sprintf('%3.d. %s', curExperimentIdx, [curExperiment ' (' newLabelList ')']);
  end
  setappdata(netcalMainWindow, 'project', project);
  success = true;
end

%--------------------------------------------------------------------------
function menuClearLog(~, ~)
  hs.logPanelEditBox.setText('<html><head></head><body></body></html>');
  logMessage(hs.logPanelEditBox, [appName ' v' currVersion]);
end
%--------------------------------------------------------------------------
function menuCloseFigures(~, ~)
  figList = findall(0, 'Tag', 'netcalPlot');
  if(~isempty(figList))
    for it = 1:length(figList)
      close(figList(it));
    end
  end
end

%--------------------------------------------------------------------------
function menuPreferences(~, ~)
  [success, netcalOptionsCurrent] = preloadOptions([], netcalOptions, netcalMainWindow, true, false);
  if(success)
    if(length(recentProjectsList) > netcalOptionsCurrent.numberRecentProjects)
      recentProjectsList = recentProjectsList(1:netcalOptionsCurrent.numberRecentProjects);
    end
    updateMenu();
    updateProjectTree();
    setappdata(netcalMainWindow, 'netcalOptionsCurrent', netcalOptionsCurrent);
    
    % Apply some changes
    treeFontSize = netcalOptionsCurrent.treeFontSize;
    baseTreeFont = java.awt.Font('Courier', java.awt.Font.PLAIN, netcalOptionsCurrent.treeFontSize);  % font name, style, size
    projectTree.jCellRenderer.setFont(baseTreeFont);
    pipelineFunctionsTree.jCellRenderer.setFont(baseTreeFont);
    pipelineTree.jCellRenderer.setFont(baseTreeFont)
    saveOptions();
  end
end

%--------------------------------------------------------------------------
function menuAggregatedCompareExperiments(~, ~)
  project = getappdata(netcalMainWindow, 'project');
  fullNames = namesWithLabels();
  if(sum(project.checkedExperiments) == 0)
    logMsg('No checked experiments found', 'e');
    return;
  else
    checkedExperiments = find(project.checkedExperiments);
  end
  if(mod(length(checkedExperiments), 2))
    logMsg('Compare experiments requires an even number of experiments', 'e');
  end
  % Time to merge
  experiment = load([project.folderFiles project.experiments{checkedExperiments(1)} '.exp'], '-mat', 'traceGroups', 'traceGroupsNames');
  firstExperiment = experiment;
  populationsBefore = zeros(round(length(checkedExperiments)/2), length(experiment.traceGroups.classifier));
  populationsAfter = zeros(round(length(checkedExperiments)/2), length(experiment.traceGroups.classifier));
  populationsTransitions = zeros(length(experiment.traceGroups.classifier), length(experiment.traceGroups.classifier), round(length(checkedExperiments)/2));
  
  ncbar('Processing experiments');
  for it = 1:2:length(checkedExperiments)
    experiment = load([project.folderFiles project.experiments{checkedExperiments(it)} '.exp'], '-mat', 'traceGroups', 'traceGroupsNames', 'ROI', 'name');
    experimentAfter = load([project.folderFiles project.experiments{checkedExperiments(it+1)} '.exp'], '-mat', 'traceGroups', 'traceGroupsNames', 'ROI', 'name');
    [idx, ID, success] = findValidROI(experiment, experimentAfter);
    if(~success)
      return;
    end
    
    for i = 1:length(experiment.traceGroups.classifier)
      populationsBefore((it+1)/2, i) = numel(intersect(idx{1},experiment.traceGroups.classifier{i}));
    end
    populationsAfter = zeros(size(experimentAfter.traceGroups.classifier))';
    for i = 1:length(experimentAfter.traceGroups.classifier)
      populationsAfter((it+1)/2, i) = numel(intersect(idx{2},experimentAfter.traceGroups.classifier{i}));
    end
    for i = 1:length(experiment.traceGroups.classifier)
      for j= 1:length(experimentAfter.traceGroups.classifier)
        groupPrev = intersect(idx{1},experiment.traceGroups.classifier{i});
        groupAfter = intersect(idx{2},experimentAfter.traceGroups.classifier{j});
        repeats = ismember(groupPrev, groupAfter);
        populationsTransitions(i,j, (it+1)/2) = sum(repeats);
      end
    end
    ncbar.update((it+1)/2/(length(checkedExperiments)/2));
  end
  ncbar.close();
  [hFigW, project] = viewCompareExperiments(project, firstExperiment, populationsBefore, populationsTransitions);
  
  setappdata(netcalMainWindow, 'project', project);

end

%--------------------------------------------------------------------------
function menuAggregatedPCA(~, ~, ~)
  project = getappdata(netcalMainWindow, 'project');
  if(sum(project.checkedExperiments) == 0)
    logMsg('No checked experiments found', 'e');
    return;
  else
    checkedExperiments = find(project.checkedExperiments);
  end
  
  % Preload the groups from the first checked experiment and select the appropiate one
  experiment = load([project.folderFiles project.experiments{checkedExperiments(1)} '.exp'], '-mat', 'traceGroups', 'traceGroupsNames');
  if(~isfield(experiment, 'traceGroups'))
    % First check loading the full experiment (in case the groups are old)
    [experiment, project] = loadExperiment([project.folderFiles project.experiments{checkedExperiments(1)} '.exp'], 'verbose', false, 'project', project);
    if(~isfield(experiment, 'traceGroups'))
      logMsg('No trace groups found', 'e');
      return;
    end
  end
  groupNames = getExperimentGroupsNames(experiment);
  % Select the population
  [selectedPopulations, success] = listdlg('PromptString', 'Select groups', 'SelectionMode', 'multiple', 'ListString', groupNames);
  if(~success)
    return;
  end
  selectedPopulations = groupNames(selectedPopulations);
  
  fullSpikeFeatures = [];
  ncbar('Processing experiments');
  for it = 1:length(checkedExperiments)
    experiment = load([project.folderFiles project.experiments{checkedExperiments(it)} '.exp'], '-mat', 'spikeFeatures', 'spikeFeaturesNames', 'traceGroups', 'traceGroupsNames', 'name');
   
    % Error checks
    if(~isfield(experiment, 'spikeFeatures') || isempty(experiment.spikeFeatures) || ~isfield(experiment, 'spikeFeaturesNames') || isempty(experiment.spikeFeaturesNames))
      errMsg = sprintf('Features missing on experiment %s', project.experiments{checkedExperiments(it)});
      logMsg(errMsg, 'e');
      ncbar.close();
      return;
    end
    if(~isfield(experiment, 'traceGroups') || isempty(experiment.traceGroups))
      % First check loading the full experiment (in case the groups are old)
      [experiment, project] = loadExperiment([project.folderFiles project.experiments{checkedExperiments(it)} '.exp'], 'verbose', false, 'project', project);
      if(~isfield(experiment, 'traceGroups') || isempty(experiment.traceGroups))
        errMsg = sprintf('traceGroups missing on experiment %s', project.experiments{checkedExperiments(it)});
        logMsg(errMsg, 'e');
        ncbar.close();
        return;
      end
    end
        
    for it2 = 1:length(selectedPopulations)
      subset = getExperimentGroupMembers(experiment, selectedPopulations{it2});
      try
        tmpFeatures = [experiment.spikeFeatures(subset, :), subset(:), ones(size(subset(:)))*checkedExperiments(it)];
      catch ME
        logMsg(sprintf('Something was wrong getting the features from %s in experiment %s', selectedPopulations{it2}, experiment.name), 'e');
        logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        
      end
      % Inconsistency check
      if(~isempty(fullSpikeFeatures) && size(fullSpikeFeatures,2) ~= size(tmpFeatures, 2))
          errMsg = sprintf('Number of features on experiment %s inconsistent with the previous ones', project.experiments{checkedExperiments(it)});
          logMsg(errMsg ,'e');
          ncbar.close();
          return;
      end
      fullSpikeFeatures = [fullSpikeFeatures; tmpFeatures];
    end
    ncbar.update(it/length(checkedExperiments));
  end
  ncbar.close();
  
  if(isfield(project, 'PCA') && isfield(project.PCA, 'experimentList') && isfield(project.PCA, 'clusterIdx'))
    if(length(project.PCA.experimentList) ~= length(checkedExperiments))
      project.PCA.clusterIdx = [];
    elseif(size(project.PCA.clusterIdx, 1) ~= size(fullSpikeFeatures, 1))
      project.PCA.clusterIdx = [];
    else
      for i = 1:length(project.PCA.experimentList)
        % If the experiment list is not equal to the old one, delete
        % the old clusterIdx
        if(project.PCA.experimentList(i) ~= checkedExperiments(i))
          project.PCA.clusterIdx = [];
          break;
        end
      end
    end
  end
  project.PCA.experimentList = checkedExperiments';

  addFigure(viewPCA(project, fullSpikeFeatures, experiment.spikeFeaturesNames, 'PCA'));
    
  updateMenu();
  updateProjectTree();
end

%--------------------------------------------------------------------------
function menuAggregatedStimulationPCA(~, ~, ~)
  featuresField = 'KClProtocolData';
  project = getappdata(netcalMainWindow, 'project');
  if(sum(project.checkedExperiments) == 0)
    logMsg('No checked experiments found', 'e');
    return;
  else
    checkedExperiments = find(project.checkedExperiments);
  end
  
  % Preload the groups from the first checked experiment and select the appropiate one
  experiment = load([project.folderFiles project.experiments{checkedExperiments(1)} '.exp'], '-mat', 'traceGroups', 'traceGroupsNames');
  if(~isfield(experiment, 'traceGroups'))
    % First check loading the full experiment (in case the groups are old)
    [experiment, project] = loadExperiment([project.folderFiles project.experiments{checkedExperiments(1)} '.exp'], 'verbose', false, 'project', project);
    if(~isfield(experiment, 'traceGroups'))
      logMsg('No trace groups found', 'e');
      return;
    end
  end
  groupNames = getExperimentGroupsNames(experiment);
  % Select the population
  [selectedPopulations, success] = listdlg('PromptString', 'Select groups', 'SelectionMode', 'multiple', 'ListString', groupNames);
  if(~success)
    return;
  end
  selectedPopulations = groupNames(selectedPopulations);
  
  fullFeatures = [];
  ncbar('Processing experiments');
  for it = 1:length(checkedExperiments)
    experiment = load([project.folderFiles project.experiments{checkedExperiments(it)} '.exp'], '-mat', featuresField, 'traceGroups', 'traceGroupsNames', 'name', 'ROI', 't');
   
    % Error checks
    if(~isfield(experiment, featuresField) || isempty(experiment.(featuresField)))
      errMsg = sprintf('Features missing on experiment %s', project.experiments{checkedExperiments(it)});
      logMsg(errMsg, 'e');
      ncbar.close();
      return;
    end
    if(~isfield(experiment, 'traceGroups') || isempty(experiment.traceGroups))
      % First check loading the full experiment (in case the groups are old)
      [experiment, project] = loadExperiment([project.folderFiles project.experiments{checkedExperiments(it)} '.exp'], 'verbose', false, 'project', project);
      if(~isfield(experiment, 'traceGroups') || isempty(experiment.traceGroups))
        errMsg = sprintf('traceGroups missing on experiment %s', project.experiments{checkedExperiments(it)});
        logMsg(errMsg, 'e');
        ncbar.close();
        return;
      end
    end
        
    for it2 = 1:length(selectedPopulations)
      %subset = getExperimentGroupMembers(experiment, selectedPopulations{it2});
      try
        %tmpFeatures = [experiment.spikeFeatures(subset, :), subset(:), ones(size(subset(:)))*checkedExperiments(it)];
        [featuresList, featuresNames] = getKClFeatures(experiment, selectedPopulations{it2}, 'ROI INDEX');
        
        tmpFeatures = [featuresList, ones(size(featuresList, 1), 1)*checkedExperiments(it)];
      catch ME
        logMsg(sprintf('Something was wrong getting the features from %s in experiment %s', selectedPopulations{it2}, experiment.name), 'e');
        logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        
      end
      % Inconsistency check
      if(~isempty(fullFeatures) && size(fullFeatures,2) ~= size(tmpFeatures, 2))
          errMsg = sprintf('Number of features on experiment %s inconsistent with the previous ones', project.experiments{checkedExperiments(it)});
          logMsg(errMsg ,'e');
          ncbar.close();
          return;
      end
      fullFeatures = [fullFeatures; tmpFeatures];
    end
    ncbar.update(it/length(checkedExperiments));
  end
  ncbar.close();
  
  if(isfield(project, 'stimulationPCA') && isfield(project.stimulationPCA, 'experimentList') && isfield(project.stimulationPCA, 'clusterIdx'))
    if(length(project.stimulationPCA.experimentList) ~= length(checkedExperiments))
      project.stimulationPCA.clusterIdx = [];
    elseif(size(project.stimulationPCA.clusterIdx, 1) ~= size(fullFeatures, 1))
      project.stimulationPCA.clusterIdx = [];
    else
      for i = 1:length(project.stimulationPCA.experimentList)
        % If the experiment list is not equal to the old one, delete
        % the old clusterIdx
        if(project.stimulationPCA.experimentList(i) ~= checkedExperiments(i))
          project.stimulationPCA.clusterIdx = [];
          break;
        end
      end
    end
  end
  project.stimulationPCA.experimentList = checkedExperiments';
  
  [selectedFeatures, success] = listdlg('PromptString', 'Select features', 'SelectionMode', 'multiple', 'ListString', featuresNames(1:end-1));  % Remove ROI from the names
  if(success)
  else
    return;
  end
  
  % Need to readd by hand the last two features (experiment number and ROIs)
  addFigure(viewPCA(project, fullFeatures(:, [selectedFeatures, size(fullFeatures,2)-1, size(fullFeatures,2)]), featuresNames(selectedFeatures), 'stimulationPCA'));

  updateMenu();
  updateProjectTree();
end

%--------------------------------------------------------------------------
function menuProjectClose(hObject, ~, appName)
  project = getappdata(netcalMainWindow, 'project');

  if(~isempty(project))
    choice = questdlg('Do you want to save the project?', ...
    'Close project', ...
    'Yes', 'No', 'Cancel', 'Cancel');

    switch choice
      case 'Yes'
        menuProjectSave(hObject);
      case 'No'
      case 'Cancel'
        return;
    end
  end

  logMsg('');
  logMsg('----------------------------------');
  MSG = ['Closing project ' project.name];
  logMsg([datestr(now, 'HH:MM:SS'), ' ', MSG], 'w');
  logMsg('----------------------------------');

  clearAppData(netcalMainWindow);
  netcalMainWindow.Name = [appName, ' - no project selected'];
  updateMenu();
  resetProjectTree();
end

%--------------------------------------------------------------------------
function hFig = splashScreen(~, ~)
  hFig = SplashScreen([appName ' v' currVersion], [appFolder filesep 'internal' filesep 'gui' filesep 'images' filesep 'logo_netcal_400.png']);
  % Let's recenter it
  if(~DEVELOPMENT)
    hFig.addText(18, hFig.Height-10, ['v' currVersion ' pre-release'] , 'FontSize', 20, 'FontWeight', 'bold', 'Color', 'k', 'Shadow', 'off');
  else
    hFig.addText(18, hFig.Height-10, ['v' currVersion ' DEV'] , 'FontSize', 20, 'FontWeight', 'bold', 'Color', 'k', 'Shadow', 'off');
  end
end


%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%--------------------------------------------------------------------------
function updateMenu()
  menuHandles = findall(netcalMainWindow, 'type', 'uimenu');
  for it = 1:length(menuHandles)
    % Do nothing for context menus
    if(isa(menuHandles(it).Parent, 'matlab.ui.container.ContextMenu'))
      continue;
    end
    menuHandles(it).Enable = 'off';
    menuHandles(it).Checked = 'off';
  end
  % Conditions for the project menu
  hs.menu.project.root.Enable = 'on';
  hs.menu.project.new.Enable = 'on';
  hs.menu.project.load.Enable = 'on';
  hs.menu.project.preferences.Enable = 'on';
  hs.menu.project.clearLog.Enable = 'on';
  hs.menu.project.closeAll.Enable = 'on';
  hs.menu.project.quit.Enable = 'on';
  fields = fieldnames(hs.menu.project.update);
  for i = 1:length(fields)
    hs.menu.project.update.(fields{i}).Enable = 'on';
  end

  % Update load recent menus    
  if(length(recentProjectsList) >= 1)
    for it = 1:length(hs.menu.project.loadRecentList)
      delete(hs.menu.project.loadRecentList(it));
    end
    hs.menu.project.loadRecent.Enable = 'on';
    for it = length(recentProjectsList):-1:1
      if(isempty(recentProjectsList{it}))
        continue;
      end
      %if(isstring(recentProjectsList{it}))
      %  recentProjectsList{it} = char(recentProjectsList{it});
      %end
      [fpa, fpb, fpc] = fileparts(recentProjectsList{it});
      %shortName = [fpa filesep fpb fpc];
      if(~isempty(fpa))
        shortName = [fpa filesep fpb];
      else
        shortName = fpb;
      end
      %shortName = recentProjectsList{it};
      if(length(shortName) > 47)
        shortName = ['...' shortName(end-46:end)];
      end
      fullName = [fpa filesep fpb fpc];
      fullNameSplit = '<html><body>';
      splitPoints = 0:40:length(fullName);
      if(splitPoints(end) ~= length(fullName))
        splitPoints = [splitPoints, length(fullName)];
      end
      for itt = 1:(length(splitPoints)-1)
        if(itt > 1)
          fullNameSplit = [fullNameSplit, '<br />', fullName(splitPoints(itt)+1:splitPoints(itt+1))];
        else
          fullNameSplit = [fullNameSplit, fullName(splitPoints(itt)+1:splitPoints(itt+1))];
        end
      end
      fullNameSplit = [fullNameSplit, '</body></html>'];
      if(isunix && ~ismac)
        menuLabel = shortName;
      else
        menuLabel = fullNameSplit;
      end

      hs.menu.project.loadRecentList = [hs.menu.project.loadRecentList; ...
        uimenu(hs.menu.project.loadRecent, 'Label', menuLabel, 'Enable', 'on', ...
        'Checked', 'off', 'Callback', {@menuProjectLoad, recentProjectsList{it}})];
    end
  else
    for it = 1:length(hs.menu.project.loadRecentList)
      delete(hs.menu.project.loadRecentList(it));
    end
  end

  project = getappdata(netcalMainWindow, 'project');
  if(~isempty(project))
    hs.menu.project.close.Enable = 'on';
    hs.menu.project.save.Enable = 'on';
    hs.menu.project.export.Enable = 'on';
    hs.menu.project.rename.Enable = 'on';
  end

  % Conditions for the experiment menu
  if(~isempty(project))
    hs.menu.experiment.root.Enable = 'on';
    hs.menu.experiment.add.Enable = 'on';
    hs.menu.experiment.addBatch.Enable = 'on';
    hs.menu.experiment.import.Enable = 'on';
  end

  % Update experiment selection menus
  if(~isempty(project) && strcmp(experimentSelectionMode, 'single'))
    hs.menu.experiment.override.root.Enable = 'on';
    hs.menu.experiment.workspace.root.Enable = 'on';
    hs.menu.experiment.restore.Enable = 'on';
    
    if(isfield(project, 'experiments') && ~isempty(project.experiments))
      subfields = fieldnames(hs.menu.experiment.override);
      for it = 1:length(subfields)
        hs.menu.experiment.override.(subfields{it}).Enable = 'on';
      end
      subfields = fieldnames(hs.menu.experiment.workspace);
      for it = 1:length(subfields)
        hs.menu.experiment.workspace.(subfields{it}).Enable = 'on';
      end
    end
  end
  % Some overrides might be available on batch mode
  if(~isempty(project) && ~strcmp(experimentSelectionMode, 'single'))
    hs.menu.experiment.override.root.Enable = 'on';
    if(isfield(project, 'experiments') && ~isempty(project.experiments))
      hs.menu.experiment.override.fps.Enable = 'on';
      hs.menu.experiment.override.handle.Enable = 'on';
      hs.menu.experiment.override.numFrames.Enable = 'on';
      %hs.menu.experiment.override.precaching.Enable = 'on';
      %hs.menu.experiment.override.precachingExtensive.Enable = 'on';
    end
  end
  
  if(~isempty(project))
    printProjectInfo(project);
  end
  
  % Update modules menu
  try
    updateModulesMenu();
  catch ME
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
  end

  % Conditions for plugins menu
  hs.menu = pluginChecker(appFolder, hs.menu);
  hs.menu = docChecker(appFolder, hs.menu);
  optionsChecker();

  % Conditions for the help menu (all on)
  for j = fieldnames(hs.menu.help)'
    if(isa(hs.menu.help.(j{:}),'matlab.ui.container.Menu'))
      if(length(hs.menu.help.(j{:})) == 1)
        hs.menu.help.(j{:}).Enable = 'on';
      end
    end
  end

  resizeHandle = getappdata(netcalMainWindow, 'ResizeHandle');
  if(~isa(resizeHandle,'function_handle'))
    netcalMainWindow.ResizeFcn = @resizeCallback;
    resizeHandle = netcalMainWindow.ResizeFcn;
    setappdata(netcalMainWindow, 'ResizeHandle', resizeHandle);
  end
end

%--------------------------------------------------------------------------
function printSavedExperimentInfo(varargin)
  if(nargin > 0)
    experimentFile = varargin{1};
  else
    experimentFile = [];
  end
  switch experimentSelectionMode
    case {'multiple', 'pipeline'}
      return;
  end

  if(isempty(experimentFile))
    try
      project = getappdata(netcalMainWindow, 'project');
      project.currentExperiment = find(projectTree.Root.Children == projectTree.SelectedNodes(1));
      experimentName = project.experiments{project.currentExperiment};
      experimentFile = [project.folderFiles experimentName '.exp'];
      setappdata(netcalMainWindow, 'project', project);
    catch
    end
  end
  
  hlog = getappdata(netcalMainWindow, 'infoHandle');
  % Capture scrollbar position
  %hs.infoPanel.Enable = 'off';
  jpan = findjobj(hs.infoPanel);
  vp = jpan.getViewport;
  vpp = vp.getViewPosition;
    
  if(~isempty(experimentFile))
    try
      %tic
      warning('off', 'MATLAB:load:variableNotFound');
      experiment = load(experimentFile, '-mat', 'name', 'handle', 'folder', 'totalTime', 'width', 'height', 'pixelType', 'numFrames', 'fps', 'metadata', 'ROI', 'traceGroupsNames', 'traceGroups', 'rawTraces', 'traces', 'spikes', 'affineTransformEnabled');
      warning('on', 'MATLAB:load:variableNotFound');
      %experiment = load(experimentFile, '-mat', 'name', 'handle', 'folder', 'totalTime', 'width', 'height', 'pixelType', 'numFrames', 'fps', 'metadata', 'ROI');
      %toc
      %stateVariables = who('-file', experimentFile); % This takes too long to load
    catch
      return;
    end
    if(isfield(experiment, 'handle') && ~isempty(experiment.handle) && experiment.handle(1) ~= 0)
      [fpa, fname, ext] = fileparts(experiment.handle);
      fpa = [fpa filesep];
    else
      fpa = [];
      fname = 'none';
      ext = [];
    end
    msgList = {'clear', ...
               sprintf('<b>Name:</b>       %s', experiment.name), ...
               sprintf('<b>File:</b>       %s', [fpa fname ext]), ...
               sprintf('<b>Folder:</b>     %s', experiment.folder), ...
               sprintf('<b>Duration:</b>   %.2f s - %d frames', experiment.totalTime, experiment.numFrames), ...
               sprintf('<b>FPS:</b>   %.2f fps', experiment.fps), ...
               sprintf('<b>Size:</b>       %dx%d px', experiment.width, experiment.height), ...
               sprintf('<b>Pixel type:</b> %s', experiment.pixelType)};
    if(isfield(experiment, 'metadata') && isfield(experiment.metadata, 'info'))
      if(~isempty(experiment.metadata.info))
        msgList{end+1} = sprintf('<b>Info:</b> %s', experiment.metadata.info);
      else
        msgList{end+1} = sprintf('<b>Info:</b> none');
      end
    end
    msgList{end+1} = '-------';
    
    msgList{end+1} = sprintf('<b>Additional background correction</b>');
    if(isfield(experiment, 'backgroundImageCorrection') && isfield(experiment.backgroundImageCorrection, 'active') && experiment.backgroundImageCorrection.active)
      switch params.backgroundImageCorrection.mode
        case 'substract'
          msgList{end+1} = sprintf('Background image substracted to original data');
        case 'add'
          msgList{end+1} = sprintf('Background image added to original data');
        case 'multiply'
          msgList{end+1} = sprintf('Background image multiplied to original data');
          case 'divide'
          msgList{end+1} = sprintf('Background image divided to original data');
      end
    else
      msgList{end+1} = sprintf('None');
    end
    msgList{end+1} = '-------';
    msgList{end+1} = sprintf('<b>Drift correction</b>');
    if(isfield(experiment, 'affineTransformEnabled')) 
      if(experiment.affineTransformEnabled)
        msgList{end+1} = sprintf('Enabled');
      else
        msgList{end+1} = sprintf('Disabled');
      end
    else
      msgList{end+1} = sprintf('None');
    end
    if(isfield(experiment, 'denoisedData'))
      msgList{end+1} = '-------';
      baseMsg = 'Denoised data';
      msgList{end+1} = sprintf('<b>%s:</b> yes', baseMsg);
    end
    msgList{end+1} = '-------';
    baseMsg = 'ROI';
    if(isfield(experiment, 'ROI'))
      msgList{end+1} = sprintf('<b>%s:</b> %d', baseMsg, length(experiment.ROI));
    else
      msgList{end+1} = sprintf('<b>%s:</b> none', baseMsg);
    end
    baseMsg = 'raw traces';
    %if(any(strcmp(stateVariables, 'rawTraces')))
    if(isfield(experiment, 'rawTraces'))
      msgList{end+1} = sprintf('<b>%s:</b> yes', baseMsg);
    else
      msgList{end+1} = sprintf('<b>%s:</b> no', baseMsg);
    end
    baseMsg = 'smoothed traces';
    %if(any(strcmp(stateVariables, 'traces')))
    if(isfield(experiment, 'traces'))
      msgList{end+1} = sprintf('<b>%s:</b> yes', baseMsg);
    else
      msgList{end+1} = sprintf('<b>%s:</b> no', baseMsg);
    end
    baseMsg = 'spikes';
    %if(any(strcmp(stateVariables, 'spikes')))
    if(isfield(experiment, 'spikes'))
      msgList{end+1} = sprintf('<b>%s:</b> yes', baseMsg);
    else
      msgList{end+1} = sprintf('<b>%s:</b> no', baseMsg);
    end
    try
      if(isfield(experiment, 'traceGroupsNames'))
        fields = fieldnames(experiment.traceGroupsNames);
        msgList{end+1} = '-------';
          msgList{end+1} = '<b>Groups</b>';
        if(length(fields) < 2)
          msgList{end+1} = 'none';
        end
        for it = 1:length(fields)
          if(strcmp(fields{it}, 'everything'))
            continue;
          end
          try
            subfields = experiment.traceGroupsNames.(fields{it});
            subfieldsCount = cellfun(@length, experiment.traceGroups.(fields{it}));
            subfieldStr = ['<b>%s:</b> ', repmat('%s (%d), ',1,length(subfields))];
            subfieldStr = subfieldStr(1:end-2);
            tmpData = [subfields(:) num2cell(subfieldsCount)]';
            msgList{end+1} = sprintf(subfieldStr, fields{it}, tmpData{:});
          end
        end
      end
    catch
    end
    if(isfield(experiment, 'metadata'))
%       try
%         if(isstruct(experiment.metadata))
%           msgList{end+1} = '-------';
%           msgList{end+1} = sprintf('<b>Metadata</b>');
%           fields = fieldnames(experiment.metadata);
%           for itt = 1:length(fields)
%             msgList{end+1} = sprintf('<b>%s:</b> %s', fields{itt}, experiment.metadata.(fields{itt}));
%           end
%           msgList{end+1} = fieldStr;
%         else
%           msgList{end+1} = '-------';
%           msgList{end+1} = sprintf('<b>Metadata</b>');
%           msgList{end+1} = sprintf('%s', experiment.metadata);
%         end
%       end
      msgList{end+1} = '-------';
      msgList{end+1} = sprintf('<b>Metadata</b>');
      fullText = evalc('disp(experiment.metadata)');
      fullTextSplit = strsplit(fullText,'\n');
      for itt = 1:length(fullTextSplit)
        msgList{end+1} = sprintf('%s', fullTextSplit{itt}); % SO UGLY
      end
    end
    logMessage(hlog, msgList, 'i', false);
    % for it = 1:length(msgList)
       %logMessage(hlog, strrep(msgList{it}, ' ', '&nbsp;'));
    %   logMessage(hlog, msgList{it});
    % end
  else
    if(isempty(project))
      logMessage(hlog, 'No active project', 'w');
      logMessage(hlog, '', 'w');
      logMessage(hlog, 'Please load a project or create a new one to get started', 'w');
      logMessage(hlog, '', 'w');
      logMessage(hlog, 'You can also drag and drop a recording to automatically create a new project', 'w');
    else
      logMessage(hlog, 'No experiment selected');
    end
  end

 
   % Get old scrollbar position
    jpan = findjobj(hs.infoPanel);
    vp = jpan.getViewport;
    vp.setViewPosition(vpp);
    %hs.infoPanel.Enable = 'on';
end

%--------------------------------------------------------------------------
function printProjectInfo(project)
  switch experimentSelectionMode
    case 'single'
      return;
  end
  
  hlog = getappdata(netcalMainWindow, 'infoHandle');
  
  msgList = {'clear'};
  if(~isempty(project))
    msgList{end+1} = sprintf('<b>Name:</b> %s', project.name);
    msgList{end+1} = sprintf('<b>Folder:</b> %s', project.folder);
    if(isfield(project, 'experiments') && ~isempty(project.experiments))
      msgList{end+1} = sprintf('<b>Experiments:</b> %d', length(project.experiments));
    else
      msgList{end+1} = sprintf('<b>Experiments:</b> 0');
    end
    if(isfield(project, 'checkedExperiments') && ~isempty(project.checkedExperiments))
      msgList{end+1} = sprintf('<b>Active experiments:</b> %d', sum(project.checkedExperiments));
    end
  else
    msgList{end+1} = '<b>No project selected</b>';
  end
  logMessage(hlog, msgList, 'i', false);
end

%%% NOT IN USE
%--------------------------------------------------------------------------
% function releaseNotesChecker()
%   numberVersionsShow = 3;
% 
%   fID = fopen([appFolder filesep 'README.md'], 'r');
%   readingVersion = 0;
%   while(~feof(fID))
%     curLine = fgetl(fID);
%     if(strfind(curLine, ['## [' currVersion ']']))
%       readingVersion = numberVersionsShow;
%       % Here we need to pass the gui handle, since this is never called
%       % from a callback function
%       logMsg('----------------------------------', netcalMainWindow);
%       logMsg('VERSION NOTES', netcalMainWindow, 'w');
%       logMsg('----------------------------------', netcalMainWindow);
%       logMsg(curLine, netcalMainWindow, 'w');
%       continue;
%     end
%     if(readingVersion & strfind(curLine, '## ['))
%       readingVersion = readingVersion - 1;
%       if(readingVersion)
%         logMsg('----------------------------------', netcalMainWindow);
%         logMsg(curLine, netcalMainWindow, 'w');
%         continue;
%       else
%         logMsg('----------------------------------', netcalMainWindow);
%       end
%     end
%     if(readingVersion & strfind(curLine, ['[' currVersion ']']))
%       readingVersion = 0;
%       logMsg('----------------------------------', netcalMainWindow);
%     end
%     if(readingVersion)
%       logMsg(curLine, netcalMainWindow);
%     end
%   end
%   fclose(fID);
% end

%--------------------------------------------------------------------------
function needsUpdating = updateChecker(varargin)
  updateIsRunning = true;
  if(nargin < 1)
    silent = false;
  else
    silent = varargin{1};
  end
  needsUpdating = false;
  % Check if updater is true on the preferences
  netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
  if(iscell(netcalOptionsCurrent.update))
    netcalOptionsCurrent.update = 'ask';
    setappdata(netcalMainWindow, 'netcalOptionsCurrent', netcalOptionsCurrent);
  end

  if(strcmpi(netcalOptionsCurrent.update, 'never'))
    if(~silent)
      logMsg('Not checking for updates...', netcalMainWindow, 'w');
      updateIsRunning = false;
      return;
    end
  end
  if(~silent)
    logMsg('Checking for updates...', netcalMainWindow);
  end

  options = weboptions('ContentType','json', 'Timeout', 15);
  try
    data = webread([updaterSource 'version'], 'host', char(getHostName(java.net.InetAddress.getLocalHost)), options);
  catch ME
    try
      data = webread([updaterSource 'version'], options);
    catch ME2
      if(~silent)
        logMsg('Checking failed', netcalMainWindow, 'e');
        logMsg(strrep(getReport(ME2),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
      end
      updateIsRunning = false;
      return;
    end
  end

  serverVersion = data.version;
  serverVersion = cellstr(strsplit(regexprep(serverVersion,'\.',' '), ' '));
  currentVersion = cellstr(strsplit(regexprep(currVersion,'\.',' '), ' '));
  needsUpdating = false;
  serverVersion = str2double(serverVersion);
  currentVersion = str2double(currentVersion);
  if(length(serverVersion) == 2)
    serverVersion = [serverVersion, 0];
  end
  if(length(currentVersion) == 2)
    currentVersion = [currentVersion, 0];
  end

  % I am sure there are better ways to do these comparisons
  if(serverVersion(1) > currentVersion(1))
    % Major update
    logMsg('-----', netcalMainWindow);
    logMsg('There is a new major release available. It will not be installed automatically.', netcalMainWindow, 'w');
    logMsg(['To install it you should download it manually from: ' updaterSource 'netcalCurrent.zip'], netcalMainWindow, 'w');
    logMsg('I recommend to install it in a different folder from the old NETCAL. In theory everything is compatible, but there are major changes, better be safe than sorry.', netcalMainWindow, 'w');
    logMsg('It is also recommended to backup your projects before testing them on the new version.', netcalMainWindow, 'w');
    logMsg('You can continue using this version, but it will not be updated anymore.', netcalMainWindow, 'w')
    logMsg('-----', netcalMainWindow)
    return;
  elseif(serverVersion(1) < currentVersion(1))
    if(~silent)
      logMsg('Current version is higher than server version', netcalMainWindow, 'w');
    end
  elseif(serverVersion(2) > currentVersion(2))
    needsUpdating = true;
  elseif(serverVersion(2) < currentVersion(2))
    if(~silent)
      logMsg('Current version is higher than server version', netcalMainWindow, 'w');
    end
  elseif(serverVersion(3) > currentVersion(3))
    needsUpdating = true;
  elseif(serverVersion(3) < currentVersion(3))
    if(~silent)
      logMsg('Current version is higher than server version', netcalMainWindow, 'w');
    end
  else
    if(~silent)
      logMsg('Current version is up to date.', netcalMainWindow);
      %%% Start the silent timer here
       if(isempty(updateTimer))
         % Every 4 hours
         updateTimer = timer('TimerFcn', @timerUpdate, ...
                            'BusyMode', 'drop', 'ExecutionMode','FixedRate',...
                            'StartDelay', 3600*4, 'Period', 3600*4, 'Tag', 'updateTimer', 'ErrorFcn', @timerUpdateError);
         start(updateTimer);
       end
    end
  end
%    if(isempty(updateTimer))
%      updateTimer = timer('TimerFcn', @timerUpdate, ...
%                         'BusyMode', 'drop', 'ExecutionMode','FixedRate',...
%                         'StartDelay', 10, 'Period', 10, 'Tag', 'updateTimer', 'ErrorFcn', @timerUpdateError);
%      start(updateTimer);
%    end

  if(needsUpdating && strcmpi(netcalOptionsCurrent.update, 'ask'))
    choice = questdlg('New version found. Do you want to update?', ...
                      'Update NETCAL', ...
                      'Yes', 'No', 'Cancel', 'Cancel');
    switch choice
      case 'Yes'
      otherwise
        logMsg('Skipping update', netcalMainWindow);
        %%% Disable the timer here
         if(~isempty(updateTimer))
           try
            stop(updateTimer);
            delete(updateTimer);
           catch
           end
         end
        updateIsRunning = false;
        return;
    end
  end
  if(needsUpdating)
    logMsg('Current version is outdated. Downloading new version...', netcalMainWindow);
    success = updateFileByFile();

    if(success)
      menuChangelog([], [], appFolder);
      logMsg([appName ' updated from version: ' currVersion ' to version: ' data.version], netcalMainWindow);
      h = msgbox({[appName ' updated from version: ' currVersion ' to version: ' data.version] 'Please restart the application'});
      uiwait(h);
      close(netcalMainWindow);
    else
      logMsg('Update failed, try to download it manually from:', netcalMainWindow, 'e');
      if(DEVELOPMENT)
        logMsg(sprintf('https://github.com/orlandi/netcalDevelopment/archive/v%d.%d.%d.zip', serverVersion(1), serverVersion(2), serverVersion(3)), netcalMainWindow, 'e');
      else
        logMsg(sprintf('https://github.com/orlandi/netcal/archive/v%d.%d.%d.zip', serverVersion(1), serverVersion(2), serverVersion(3)), netcalMainWindow, 'e');
      end
      logMsg(['or from: ' updaterSource 'netcalCurrent.zip'], netcalMainWindow, 'e');
      ncbar.close();
    end
  end
  updateIsRunning = false;
end


%--------------------------------------------------------------------------
function timerUpdate(~, ~)
  %needsUpdating = updateChecker(true);
  % Only check if an update is not already running, e.g., the dialog box is open
  if(~updateIsRunning)
    needsUpdating = updateChecker(true);
    if(needsUpdating)
      return;
    end
  end
end

%--------------------------------------------------------------------------
function timerUpdateError(~, ~)
  stop(updateTimer);
end

%--------------------------------------------------------------------------
function updateForceUpdate(~, ~)
  success = updateFileByFile(true);
  if(success)
    logMsg('Force update succeeded. Please restart the application');
    h = msgbox({'Force update succeeded. Please restart the application'});
    uiwait(h);
    close(netcalMainWindow);
  else
    logMsg('Force Update failed', 'e');
  end
end

%--------------------------------------------------------------------------
function success = updateFileByFile(varargin)
  if(nargin > 0)
    force = varargin{1};
  else
    force = false;
  end
  verbose = false;
  
  fileList = webread([updaterSource 'fileList.txt']);
  if(ispc)
    fileList = strrep(fileList, '/', '\');
  end
  % Turn each line into 2 strings to process and compare
  fileListLines = strsplit(fileList, '\n');
  filesToDownload = {};
  for i = 1:length(fileListLines)
    splitLine = strsplit(fileListLines{i});
    if(length(splitLine) > 2)
      splitLine = {strjoin(splitLine(1:end-1)), str2double(splitLine{end})};
    else
      splitLine{2} = str2double(splitLine{end});
    end
    % Now do the comparison
    currFile = dir(splitLine{1});
    % Always update netcal.m - since it might very easily have same byte length as other versions
    try
      if((force && ~strcmpi(currFile.name, 'netcal.m')) || isempty(currFile) || (currFile.bytes ~= splitLine{2} && ~strcmpi(currFile.name, 'netcal.m')))
        filesToDownload{end+1} = splitLine{1};
      end
    catch
      logMsg(sprintf('Something went wrong analyzing: %s. Skipping\n', currFile));
    end
  end
  %Always upload netcal.m last
  filesToDownload{end+1} = 'netcal.m';
  if(verbose)
    filesToDownload
  end
  ncbar.initialize(sprintf('Updating NETCAL (%d modified files)', length(filesToDownload)));
  for i = 1:length(filesToDownload)
    %[fpa, fpb, fpc] = fileparts(filesToDownload{i});
    if(checkUserModifiedFile(filesToDownload{i}))
      logMsg(sprintf('%s modified by the user. Not updating it', filesToDownload{i}), netcalMainWindow, 'w');
      continue;
    end
    %newFile = webread([updaterSource 'netcalCurrent/' filesToDownload{i}]);
    try
      [fpa, ~, ~] = fileparts(filesToDownload{i});
      if(isempty(rdir(fpa)) && ~isempty(fpa))
        mkdir(fpa);
      end
      if(verbose)
        [filesToDownload{i} ' ' [updaterSource 'netcalCurrent/' filesToDownload{i}]]
      end
      websave(filesToDownload{i}, [updaterSource 'netcalCurrent/' strrep(filesToDownload{i},'\','/')]);
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
      success = false;
      return;
    end
    if(~any(strfind(filesToDownload{i}, 'ncbar.m')))
      ncbar.update(i/length(filesToDownload));
    else
      pause(2);
      which ncbar;
      ncbar.initialize(sprintf('Updating NETCAL (%d modified files)', length(filesToDownload)));
      ncbar.update(i/length(filesToDownload));
    end
  end
  logMsg(sprintf('Updated NETCAL (%d modified files)', length(filesToDownload)), netcalMainWindow, 'w');
  pause(1);
  ncbar.close();
  success = true;
end

%--------------------------------------------------------------------------     
function optionsChecker()
  % Reset the list
  for it = 1:length(hs.menu.options.list)
    delete(hs.menu.options.list(it));
  end
  hs.menu.options.list = [];

  project = getappdata(netcalMainWindow, 'project');
  if(isempty(project))
    return;
  end
  fields = fieldnames(project);
  optionsList = {};
  optionsListClass = {};
  for it = 1:length(fields)
    if(isa(project.(fields{it}), 'baseOptions'))
      optionsList{end+1} = fields{it};
      optionsListClass{end+1} = class(project.(fields{it}));
    end
  end
  if(~isempty(optionsList))
    hs.menu.options.root.Enable = 'on';
  end
  for it = 1:length(optionsList)
    hs.menu.options.list = [hs.menu.options.list; ...
                            uimenu(hs.menu.options.root, 'Label', optionsListClass{it}, 'Enable', 'on', ...
                                   'Checked', 'off', 'Callback', {@changeProjectOption, project.(optionsList{it})})];
  end
end

%--------------------------------------------------------------------------
function changeProjectOption(~, ~, optionsClass)
  project = getappdata(netcalMainWindow, 'project');
  [success, optionsClassCurrent] = preloadOptions([], optionsClass, netcalMainWindow, true, false);
  if(success)
    project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
    setappdata(netcalMainWindow, 'project', project);
  end
end

%--------------------------------------------------------------------------
function nameWithoutLabel = removeLabel(name)
  nameWithoutLabel = name;
  project = getappdata(netcalMainWindow, 'project');

  experimentName = name;
  for it = 1:size(project.experiments,2)
    regstr = ['^' project.experiments{it} ' +('];
    if(regexp(experimentName, regstr))
      if(isfield(project, 'labels') && length(project.labels) >= it && ~isempty(project.labels{it}))
        nameWithoutLabel = strrep(experimentName, [' (' project.labels{it} ')'], '');
        return;
      end
    end
  end
end

%--------------------------------------------------------------------------
function [experimentOrder, experimentOrderInverse] = setExperimentOrder(selection, sortType, reverseSortingOrder)
  project = getappdata(netcalMainWindow, 'project');
  names = project.experiments(selection);
  Nexperiments = length(names);

  if(isfield(project, 'labels'))
    labels = project.labels(selection);
    if(strcmpi(sortType, 'label'))
      [~,experimentOrder] = sort(labels);
    else
      experimentOrder = 1:Nexperiments;
    end
  else
    experimentOrder = 1:Nexperiments;
  end

  if(reverseSortingOrder)
    experimentOrder = experimentOrder(end:-1:1);
  end
  experimentOrderInverse = zeros(size(experimentOrder));
  for it = 1:length(experimentOrder)
    experimentOrderInverse(it) = find(experimentOrder == it);
  end
end

%--------------------------------------------------------------------------
function saveOptions()
  netcalOptionsCurrent = getappdata(netcalMainWindow, 'netcalOptionsCurrent');
  if(~isempty(netcalOptionsCurrent))
    netcalOptionsCurrent = netcalOptionsCurrent.get;
    optionsFile = [appFolder filesep 'netcal.json'];
    netcalOptionsCurrent.defaultFolder = char(netcalOptionsCurrent.defaultFolder);
    netcalOptionsCurrent.recentProjectsList = recentProjectsList; 
    if(~iscell(netcalOptionsCurrent.recentProjectsList))
      netcalOptionsCurrent.recentProjectsList = num2cell(netcalOptionsCurrent.recentProjectsList);
      netcalOptionsCurrent.recentProjectsList = cellfun(@char, netcalOptionsCurrent.recentProjectsList, 'UniformOutput', false);
      netcalOptionsCurrent.recentProjectsList = unique(netcalOptionsCurrent.recentProjectsList, 'stable');
    end
    try
      optionsData = savejson([], netcalOptionsCurrent, 'ParseLogical', true);
    catch ME
      logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
      return;
    end
    fID = fopen(optionsFile, 'w');
    fprintf(fID, '%s', optionsData);
    fclose(fID);
  end
  % Also save the project pipeline
  try
    savePipeline([], [], [appFolder filesep 'pipeline.json']);
  catch ME
    logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
  end
end

%--------------------------------------------------------------------------
function loadOptions()
  optionsFile = [appFolder filesep 'netcal.json'];
  netcalOptionsCurrent = netcalOptions;
  if(exist(optionsFile, 'file'))
    try
      optionsData = loadjson(optionsFile);
    catch ME
      errMsg = {'jsonlab toolbox missing. Please install it from the installDependencies folder'};
      uiwait(msgbox(errMsg,'Error','warn'));
      optionsData = netcalOptionsCurrent;
    end
  else
    optionsData = netcalOptionsCurrent;
  end
  % Check for correct options (just in case)
  if(~ischar(optionsData.defaultFolder) && ~isa(optionsData.defaultFolder,'java.io.File'))
    optionsData.defaultFolder = appFolder;
  elseif(~exist(optionsData.defaultFolder,'dir'))
    optionsData.defaultFolder = appFolder;
  end
  if(isfield(optionsData, 'recentProjectsList'))
    if(~iscell(optionsData.recentProjectsList))
      optionsData.recentProjectsList = num2cell(optionsData.recentProjectsList);
      optionsData.recentProjectsList = cellfun(@char, optionsData.recentProjectsList, 'UniformOutput', false);
    end
    if(~isempty(optionsData.recentProjectsList))
      optionsData.recentProjectsList = unique(optionsData.recentProjectsList, 'stable');
      for it = 1:length(optionsData.recentProjectsList)
        newDir = optionsData.recentProjectsList{it};
        newDir = regexprep(newDir, '\\\\','\\');
        newDir = regexprep(newDir, '\\/','/');
        % Now, those that start with a single bar, should start with a double bar
        newDir = regexprep(newDir, '^(\\+)', '\\\\');
        
        optionsData.recentProjectsList{it} = newDir;
      end
    end
    recentProjectsList = optionsData.recentProjectsList;
  end
  netcalOptionsCurrent = netcalOptionsCurrent.set(optionsData);
  if(netcalOptionsCurrent.numberRecentProjects < length(recentProjectsList))
    recentProjectsList = recentProjectsList(1:netcalOptionsCurrent.numberRecentProjects);
  end
  setappdata(netcalMainWindow, 'netcalOptionsCurrent', netcalOptionsCurrent);
  
  set(netcalMainWindow, 'DefaultTextFontSize', netcalOptionsCurrent.mainFontSize);
  set(netcalMainWindow, 'DefaultUIControlFontSize', netcalOptionsCurrent.uiFontSize);
  
  %updateMenu();
end

%--------------------------------------------------------------------------
function figureCount = checkOpenFigures()
  figureCount = 0;
  invalidHandles = [];
  for it = 1:length(openFiguresList)
    if(ishandle(openFiguresList(it)))
      figureCount = figureCount + 1;
    else
      invalidHandles = [invalidHandles; it];
    end
  end
  openFiguresList(invalidHandles) = [];
end

%--------------------------------------------------------------------------
function addFigure(handle)
  openFiguresList = [openFiguresList; handle];
end

%--------------------------------------------------------------------------
function menu = initializeMenu(~, ~)
  % Delete the menu in case it already exists
  if(isfield(hs, 'menu'))
    fields = fieldnames(hs.menu);
    for i = 1:length(fields)
      hs.menu.(fields{i}).root
      delete(hs.menu.(fields{i}).root);
    end
  end
  
  % Now create all entries
  menu.project.root = uimenu(netcalMainWindow, 'Label', 'File');
  menu.project.new = uimenu(menu.project.root, 'Label', 'New project', 'Accelerator', 'N', 'Callback', @menuProjectNew);
  menu.project.load = uimenu(menu.project.root, 'Label', 'Load project...', 'Accelerator', 'L', 'Callback', @menuProjectLoad);
  menu.project.loadRecent = uimenu(menu.project.root, 'Label', 'Load recent project...');
  menu.project.loadRecentList = [];
  menu.project.save = uimenu(menu.project.root, 'Label', 'Save project', 'Accelerator', 'S', 'Callback', @menuProjectSave);
  menu.project.export = uimenu(menu.project.root, 'Label', 'Export project', 'Callback', @menuProjectExport);
  menu.project.rename = uimenu(menu.project.root, 'Label', 'Rename project', 'Callback', {@menuProjectRename, appName});
  menu.project.close = uimenu(menu.project.root, 'Label', 'Close project', 'Callback', {@menuProjectClose, appName});
  menu.project.update.root = uimenu(menu.project.root, 'Label', 'Update', 'Separator', 'on');
  menu.project.update.check = uimenu(menu.project.update.root, 'Label', 'Check consistency', 'Callback', {@updateCheckConsistency, updaterSource, DEVELOPMENT});
  menu.project.update.force = uimenu(menu.project.update.root, 'Label', 'Force update', 'Callback', @updateForceUpdate);
  menu.project.preferences = uimenu(menu.project.root, 'Label', 'Preferences', 'Separator', 'on', 'Callback', @menuPreferences);
  menu.project.clearLog = uimenu(menu.project.root, 'Label', 'Clear log', 'Accelerator', 'X', 'Callback', @menuClearLog);
  menu.project.closeAll = uimenu(menu.project.root, 'Label', 'Close all figures', 'Callback', @menuCloseFigures);
  
  menu.project.quit = uimenu(menu.project.root, 'Label', 'Exit', 'Accelerator', 'Q', 'Callback', 'close(gcbf)', 'Separator', 'on');
  
  menu.experiment.root = uimenu(netcalMainWindow, 'Label', 'Experiment');
  menu.experiment.add = uimenu(menu.experiment.root, 'Label', 'Add from movie/stack...', 'Callback', @menuExperimentAdd);
  menu.experiment.addBatch = uimenu(menu.experiment.root, 'Label', 'Add multiple movies...', 'Callback', @menuExperimentAddBatch);
  menu.experiment.import = uimenu(menu.experiment.root, 'Label', 'Import from project...',  'Callback', @menuExperimentImport);
  menu.experiment.override.root = uimenu(menu.experiment.root, 'Label', 'Override');
  menu.experiment.override.fps = uimenu(menu.experiment.override.root, 'Label', 'Change fps', 'Callback', @menuExperimentChangeFPS);
  menu.experiment.override.handle = uimenu(menu.experiment.override.root, 'Label', 'Change video file', 'Callback', @menuExperimentChangeHandle);
  menu.experiment.override.numFrames = uimenu(menu.experiment.override.root, 'Label', 'Change number of frames', 'Callback', @menuExperimentChangeNumFrames);
  menu.experiment.override.precaching = uimenu(menu.experiment.override.root, 'Label', 'Force HIS precaching', 'Callback', {@menuExperimentForceHISprecaching, 'fast'});
  menu.experiment.override.precachingExtensive = uimenu(menu.experiment.override.root, 'Label', 'Force HIS extensive precaching', 'Callback', {@menuExperimentForceHISprecaching, 'normal'});
  menu.experiment.workspace.root = uimenu(menu.experiment.root, 'Label', 'Workspace');
  menu.experiment.workspace.export = uimenu(menu.experiment.workspace.root, 'Label', 'Export to MATLAB workspace', 'Callback', @experimentToWorkspace);
  menu.experiment.workspace.import = uimenu(menu.experiment.workspace.root, 'Label', 'Import from MATLAB workspace', 'Callback', @importExperimentFromWorkspace);
  menu.experiment.restore = uimenu(menu.experiment.root, 'Label', 'Restore backup', 'Callback', @menuExperimentRestoreBackup, 'Separator', 'on');
  
  % Now for the modules
  menu.modulesMenu = initializeModulesMenu();

  % Now plugins
  menu.plugins.root = uimenu(netcalMainWindow, 'Label', 'Plugins');
  menu.plugins.list = [];

  menu.options.root = uimenu(netcalMainWindow, 'Label', 'Options');
  menu.options.list = [];
  
  menu.docs.root = uimenu(netcalMainWindow, 'Label', 'Tutorials');
  menu.docs.list = [];
  % Now help
  menu.help.root = uimenu(netcalMainWindow, 'Label', 'Help');
  menu.help.about = uimenu(menu.help.root, 'Label', 'About', 'Callback', {@menuAbout, appFolder});
  menu.help.changelog = uimenu(menu.help.root, 'Label', 'Changelog', 'Callback', {@menuChangelog, appFolder});
end

%--------------------------------------------------------------------------
function menu = initializeModulesMenu()
  try
    modules = loadModules(DEVELOPMENT);
  catch ME
    logMsg('There was a problem loading the modules', netcalMainWindow, 'e');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
    menu = {};
    return;
  end
  
  menu = {};
  for i = 1:length(modules)
    currentModule = modules{i};
    moduleName = currentModule{1};
    moduleTag = currentModule{2};
    moduleParent = currentModule{3};
    moduleCallback = currentModule{4};
    if(length(currentModule) >= 7)
      moduleSeparator = currentModule{7};
    else
      moduleSeparator = false;
    end
    moduleParentMenu = [];
    if(isempty(moduleParent))
      moduleParentMenu = netcalMainWindow;
    else
      for j = 1:length(menu)
        if(strcmp(menu{j}.Tag, moduleParent))
          moduleParentMenu = menu{j};
          break;
        end
      end
    end
    if(isempty(moduleParentMenu))
      moduleParentMenu = netcalMainWindow;
      logMsg(['Did not find correct parent for module: ' moduleName], netcalMainWindow, 'w');
    end
    
    menu{i} = uimenu(moduleParentMenu, 'Label', moduleName, 'Tag', moduleTag);
    if(~isempty(moduleCallback))
      menu{i}.Callback = moduleCallback;
    end
    if(moduleSeparator)
      menu{i}.Separator = 'on';
    end
  end
end

%--------------------------------------------------------------------------
function updateModulesMenu()
  
  project = getappdata(netcalMainWindow, 'project');
  if(isfield(project, 'currentExperiment') && isfield(project, 'experiments') && ~isempty(project.currentExperiment) && project.currentExperiment > length(project.experiments))
    project.currentExperiment = [];
  end
  % Get the current experiment fields
  try
    if(strcmp(experimentSelectionMode, 'single') && ~isempty(project) && isfield(project, 'currentExperiment') && ~isempty(project.currentExperiment))
        experimentName = project.experiments{project.currentExperiment};
        experimentFile = [project.folderFiles experimentName '.exp'];
        experimentFields = who('-file', experimentFile);
        if(isempty(experimentFields))
          project.currentExperiment = [];
        end
      else
        experimentFields = [];
    end
  catch
    logMsg('Could not load current experiment', netcalMainWindow, 'e');
    project.currentExperiment = [];
    experimentFields = [];
    experimentName = '';
  end
  modules = loadModules(DEVELOPMENT);

  menuHandles = findall(netcalMainWindow, 'type', 'uimenu');
  tagList = {menuHandles(:).Tag};
  for i = 1:length(modules)
    currentModule = modules{i};
    moduleTag = currentModule{2};
    moduleParent = currentModule{3};
    moduleDepends = currentModule{5};
    moduleCompletion = currentModule{6};
    % Find the current menu
    %currentMenu = menuHandles(find(arrayfun(@(x) strcmp(x.Tag, moduleTag), menuHandles)));
    currentMenu = menuHandles(find(strcmp(moduleTag, tagList)));
    if(isempty(currentMenu) || length(currentMenu) > 1)
      logMsg(['There was a problem with menu ' moduleTag], netcalMainWindow, 'w');
      continue;
    end
    if(isempty(project) && ~isempty(moduleParent) && isfield(currentMenu.Parent, 'Text') && ~strcmp(currentMenu.Parent.Text, 'Pipeline'))
      continue;
    end
    % Disable development modules
    if(~DEVELOPMENT)
      %if(any(strcmp(moduleTag, {'gliaAnalysis', 'networkInference', 'viewGlia'})))
      if(any(strcmp(moduleTag, {'gliaAnalysis', 'viewGlia', 'networkInferenceTDMI', 'networkInferenceGC'})))
        currentMenu.Enable = 'off';
        if(~strcmp(currentMenu.Label(end), '*'))
          currentMenu.Label = [currentMenu.Label '*'];
        end
        continue;
      end
    end

    if(isempty(moduleDepends) || strcmp(experimentSelectionMode, 'multiple'))
      currentMenu.Enable = 'on';
    end
    if(any(strcmp(experimentFields, moduleDepends)))
      currentMenu.Enable = 'on';
    end
    if(~isempty(moduleCompletion) && iscell(moduleCompletion) && any(cellfun(@(x)strcmp(experimentFields, x), moduleCompletion)))
      currentMenu.Checked = 'on';
    elseif(~isempty(moduleCompletion) && ischar(moduleCompletion) && any(strcmp(experimentFields, moduleCompletion)))
      currentMenu.Checked = 'on';
    end
    if(length(currentModule) >= 8)
      expMode = currentModule{8};
      if(any(strcmp(expMode, experimentSelectionMode)))
        currentMenu.Visible = 'on';
      else
        currentMenu.Visible = 'off';
      end
    end
  end
end


%--------------------------------------------------------------------------
function project = labelsCheck(project)
  if(isfield(project, 'labels'))
    if(length(project.experiments) > length(project.labels))
      project.labels{length(project.experiments)} = [];
    elseif(length(project.experiments) < length(project.labels))
      project.labels = project.labels(1:length(project.experiments));
    end
  end
end

%--------------------------------------------------------------------------
function updateProjectTree(~, ~)
  switch experimentSelectionMode
    case 'single'
      projectTree.Parent = hs.singleExperimentPanel;
      projectTree.SelectionType = 'single';
    case 'multiple'
      projectTree.Parent = hs.multipleExperimentPanel;
      projectTree.SelectionType = 'discontiguous';
    case 'pipeline'
      projectTree.Parent = hs.pipelineExperimentPanel;
      projectTree.SelectionType = 'discontiguous';
  end
end

%--------------------------------------------------------------------------
function resetProjectTree(~, ~)

  project = getappdata(netcalMainWindow, 'project');

  %%% Delete tree and menus
  if(~isempty(projectTree))
    if(isprop(projectTree, 'Root') && ~isempty(projectTree.Root))
      delete(projectTree.Root)
    end
    delete(projectTree)
  end
  if(~isempty(projectTreeContextMenu))
    delete(projectTreeContextMenu)
  end
  if(~isempty(projectTreeContextMenuRoot))
    delete(projectTreeContextMenuRoot)
  end
  hlog = getappdata(netcalMainWindow, 'infoHandle');
  logMessage(hlog, 'clear');
  
  if(isempty(project))
    logMessage(hlog, 'No active project' ,'w');
    logMessage(hlog, '', 'w');
    logMessage(hlog, 'Please load a project or create a new one to get started', 'w');
    logMessage(hlog, '', 'w');
    logMessage(hlog, 'You can also drag and drop a recording to automatically create a new project', 'w');
  else
    logMessage(hlog, 'No experiment selected');
  end
  
  % Reset current experiment
  if(~isempty(project) && ~isfield(project, 'currentExperiment'))
    project.currentExperiment = [];
  end

  %%% Recreate the tree
  try
    projectTree = experimentTree('Parent', hs.singleExperimentPanel, 'RootVisible', false);
    projectTree.DndEnabled = true;
    projectTree.fileDropEnabled = true;
    projectTree.Editable = false;
    projectTree.jCellRenderer.setFont(baseTreeFont);
    projectTree.NodeDroppedCallback = @(s,e)experimentTreeDnDCallback(s,e);
    projectTree.SelectionChangeFcn = @selectedMethod;
    projectTree.ButtonDownFcn = @checkedHack;
  catch ME
    logMsg('Tree creation failed failed', netcalMainWindow, 'e');
    logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    import('uiextras.jTree.*');
    projectTree = experimentTree('Parent', hs.singleExperimentPanel, 'RootVisible', false);
    projectTree.DndEnabled = true;
    projectTree.fileDropEnabled = true;
    projectTree.Editable = false;
    projectTree.jCellRenderer.setFont(baseTreeFont);
    projectTree.NodeDroppedCallback = @(s,e)experimentTreeDnDCallback(s,e);
    projectTree.ButtonDownFcn = @checkedHack;
  end

  %%% Let's create the menus
  projectTreeContextMenu = uicontextmenu('Parent', netcalMainWindow);
%   uimenu(projectTreeContextMenu, 'Label', 'Move up', 'Callback', {@moveMethod, projectTree, 'up'});
%   uimenu(projectTreeContextMenu, 'Label', 'Move down', 'Callback', {@moveMethod, projectTree, 'down'});
%   uimenu(projectTreeContextMenu, 'Label', 'Move X positions', 'Callback', {@moveMethod, projectTree, 'x'});
  uimenu(projectTreeContextMenu, 'Label', 'Assign label', 'Callback', {@assignLabelMethod, projectTree, 'assign'});
  uimenu(projectTreeContextMenu, 'Label', 'Add label', 'Callback', {@assignLabelMethod, projectTree, 'add'});
  uimenu(projectTreeContextMenu, 'Label', 'Remove label', 'Callback', {@assignLabelMethod, projectTree, 'remove'});
  uimenu(projectTreeContextMenu, 'Label', 'Change info', 'Callback', {@changeInfoMethod, projectTree}, 'Separator', 'on');
  uimenu(projectTreeContextMenu, 'Label', 'Rename', 'Callback', {@renameMethod, projectTree});
  uimenu(projectTreeContextMenu, 'Label', 'Clone', 'Callback', {@cloneMethod, projectTree});
  uimenu(projectTreeContextMenu, 'Label', 'Delete', 'Callback', {@deleteMethod, projectTree}, 'Separator', 'on');
  
  projectTreeContextMenuRoot = uicontextmenu('Parent', netcalMainWindow);
  uimenu(projectTreeContextMenuRoot, 'Label', 'Sort by name', 'Callback', {@sortMethod, projectTree, 'name'});
  uimenu(projectTreeContextMenuRoot, 'Label', 'Sort by name (inverse)', 'Callback', {@sortMethod, projectTree, 'nameInverse'});
  uimenu(projectTreeContextMenuRoot, 'Label', 'Sort by label', 'Callback', {@sortMethod, projectTree, 'label'});
  uimenu(projectTreeContextMenuRoot, 'Label', 'Sort by label (inverse)', 'Callback', {@sortMethod, projectTree, 'labelInverse'});
  uimenu(projectTreeContextMenuRoot, 'Label', 'Sort by matching pairs', 'Callback', {@sortMethod, projectTree, 'pairs'});
  uimenu(projectTreeContextMenuRoot, 'Label', 'Check all', 'Separator', 'on', 'Callback', {@selectMethod, projectTree, 'all'});
  uimenu(projectTreeContextMenuRoot, 'Label', 'Check none', 'Callback', {@selectMethod, projectTree, 'none'});
  uimenu(projectTreeContextMenuRoot, 'Label', 'Check by label', 'Callback', {@selectMethod, projectTree, 'label'});
  
  %%% If there is no project or experiments we are done
%   if(isempty(project) || ~isfield(project, 'experiments') || isempty(project.experiments))
%     updateProjectTree();
%     return;
%   end

  % If there is no project, we are done, else continue
  if(isempty(project))
    updateProjectTree();
    return;
  elseif(~isfield(project, 'experiments') || isempty(project.experiments))
    project.experiments = [];
  end

  if(~isfield(project, 'checkedExperiments'))
    project.checkedExperiments = false(length(project.experiments), 1);
    setappdata(netcalMainWindow, 'project', project);
  end
  if(length(project.checkedExperiments) < length(project.experiments))
    project.checkedExperiments(length(project.experiments)) = 0;
    setappdata(netcalMainWindow, 'project', project);
  elseif(length(project.checkedExperiments) > length(project.experiments))
    project.checkedExperiments = project.checkedExperiments(1:length(project.experiments));
    setappdata(netcalMainWindow, 'project', project);
  end

  % Check/fix the labels
  if(~isfield(project, 'labels'))
    project.labels = cell(1, length(project.experiments));
  end
  if(length(project.labels) < length(project.experiments))
    project.labels{length(project.experiments)} = [];
  end
  
  %%% Now populate the nodes
  fullNames = namesWithLabels([], netcalMainWindow);
  groupNode = {};
  
  
  for itt = 1:length(project.experiments)
    groupNode{itt} = uiextras.jTree.CheckboxTreeNode('Name', sprintf('%3.d. %s', itt, fullNames{itt}), ...
                                                     'TooltipString', fullNames{itt}, ...
                                                     'Parent', projectTree.Root, ...
                                                     'UserData', {project.experiments{itt}, project.labels{itt}, project.checkedExperiments(itt)});
    if(project.checkedExperiments(itt))
      groupNode{itt}.Checked = true;
    else
      groupNode{itt}.Checked = false;
    end
    groupNode{itt}.Parent.Children; % WEIRD HACK FOR COMPTABILITY REASON IN MATLAB < 2017
    set(groupNode{itt}, 'UIContextMenu', projectTreeContextMenu)
  end

  set(projectTree, 'UIContextMenu', projectTreeContextMenuRoot);
  projectTree.CheckboxClickedCallback = @checkedMethod;
  setappdata(netcalMainWindow, 'project', project);
  updateProjectTree();
  setappdata(netcalMainWindow, 'projectTree', projectTree);
  %%% Here are all the submethods for the menus

  
  %------------------------------------------------------------------------
  % e contains the kind of drop and drag type
  % This is called after a sucessful move
  function s = experimentTreeDnDCallback(s, e, ~)
    if(e.isFile)
      % First check if it's a project (only one)
      if(length(e.files) == 1)
        [~, ~, fpc] = fileparts(e.files{1});
        if(strcmpi(fpc, '.proj'))
          % It's a project. Let's load it!
          menuProjectLoad([], [], e.files{1});
          return;
        end
      end
      project = getappdata(netcalMainWindow, 'project');
      if(isempty(project))
        % Try to create a new project
        logMsg('There is no active project, creating a new one', 'w');
        [fpa, fpb, fpc] = fileparts(e.files{1});
        menuProjectNew([], [], 'folder', fpa);
        project = getappdata(netcalMainWindow, 'project');
        if(isempty(project))
          logMsg('Can''t add an experiment without an active project. Please create one', 'e');
          return;
        end
      end
      ncbar('Adding new experiments');
      for itb = 1:length(e.files)
        curFile = e.files{itb};
        menuExperimentAddSilent(curFile);
        ncbar.update(itb/length(e.files));
      end
      ncbar.close();
      return;
    end
    project = getappdata(netcalMainWindow, 'project');
    oldExp = project.experiments(project.currentExperiment);
    reassignExperimentsToProject(s);
    t = num2cell(project.checkedExperiments);
    [s.Root.Children(:).Checked] = t{:};
    project.currentExperiment = find(strcmp(project.experiments, oldExp));
    %s.SelectedNodes = s.Root.Children(project.currentExperiment);
    setappdata(netcalMainWindow, 'project', project);
    printSavedExperimentInfo();
  end
  
  %------------------------------------------------------------------------
  function reassignExperimentsToProject(s)
    project = getappdata(netcalMainWindow, 'project');
    project.experiments = arrayfun(@(x)x.UserData{1}, s.Root.Children, 'UniformOutput', false);
    project.labels = arrayfun(@(x)x.UserData{2}, s.Root.Children, 'UniformOutput', false);
    % In case they are not really bools
    try
      project.checkedExperiments = arrayfun(@(x)x.UserData{3}, s.Root.Children);
    catch
      for it = 1:length(s.Root.Children)
        if(s.Root.Children(it).UserData{3} == 0)
          s.Root.Children(it).UserData(3) = [];
          s.Root.Children(it).UserData{3} = false;
        else
          s.Root.Children(it).UserData(3) = [];
          s.Root.Children(it).UserData{3} = true;
        end
      end
      project.checkedExperiments = logical(project.checkedExperiments);
      project.checkedExperiments = arrayfun(@(x)x.UserData{3}, s.Root.Children);
    end
    setappdata(netcalMainWindow, 'project', project);
  end
  
  %------------------------------------------------------------------------
  function selectedMethod(hObject, ~)
    project = getappdata(netcalMainWindow, 'project');
    if(isempty(hObject.SelectedNodes))
      return;
    end
    prevExperiment = project.currentExperiment;
    project.currentExperiment = find(hObject.Root.Children == hObject.SelectedNodes(1));
    experimentName = project.experiments{project.currentExperiment};
    experimentFile = [project.folderFiles experimentName '.exp'];
    
    setappdata(netcalMainWindow, 'project', project);
    % Only need to upate the following when we change from selected experiment
    if(prevExperiment ~= project.currentExperiment)
      printSavedExperimentInfo(experimentFile);
      updateMenu();
    else
      printProjectInfo(project);
    end
    if(guiImprovements)
      checkedHack(hObject, []);
    end
  end
  
  %------------------------------------------------------------------------
  function checkedMethod(hObject, ~)
    project = getappdata(netcalMainWindow, 'project');
    project.checkedExperiments = arrayfun(@(x)x.Checked, hObject.Root.Children);
    for it = 1:length(hObject.Root.Children)
      hObject.Root.Children(it).UserData{3} = logical(project.checkedExperiments(it));
    end
    %hObject.Root.Children(5).UserData
    %arrayfun(@(x)x.Checked, hObject.Root.Children)
    printProjectInfo(project);
    setappdata(netcalMainWindow, 'project', project);
  end
  
  %------------------------------------------------------------------------
  function selectMethod(~, ~, hObject, mode)
    project = getappdata(netcalMainWindow, 'project');
    switch mode
      case 'all'
        % This is so ugly
        %t = num2cell(ones(size(hObject.Root.Children)));
        % Let's loop
        for it = 1:length(hObject.Root.Children)
          hObject.Root.Children(it).UserData{3} = true;
        end
        hObject.Root.Checked = true;
        project.checkedExperiments(:) = true;
      case 'none'
%         t = [hObject.Root.Children(:).UserData];
%         tt = num2cell(zeros(size(hObject.Root.Children)));
%         [t(3:3:end)] = tt;
%         [hObject.Root.Children(:).UserData] = t{:};
        % Let's loop
        for it = 1:length(hObject.Root.Children)
          hObject.Root.Children(it).UserData{3} = false;
        end
        hObject.Root.Checked = true;
        hObject.Root.Checked = false;
        project.checkedExperiments(:) = false;
      case 'label'
        answer = inputdlg('Select label to match', 'Check experiments by label', [1 60], {''});

        if(isempty(answer))
          return;
        end
        answer{1} = strtrim(answer{1});
        targetLabelList = strtrim(strsplit(answer{1}, ','));
        %project.checkedExperiments(:) = false;
        for it = 1:length(hObject.Root.Children)
          %hObject.Root.Children(it).UserData{3} = true;
          curLabelList = strtrim(strsplit(hObject.Root.Children(it).UserData{2}, ','));
          
          if(isempty(setdiff(targetLabelList, curLabelList)))
            hObject.Root.Children(it).UserData{3} = true;
            hObject.Root.Children(it).Checked = true;
            project.checkedExperiments(it) = 1;
          else
            hObject.Root.Children(it).UserData{3} = false;
            project.checkedExperiments(it) = 0;
            hObject.Root.Children(it).Checked = false;
          end
        end
%         for it = 1:length(project.labels)
%           if(strfind(project.labels{it}, answer{1}))
%             project.checkedExperiments(it) = 1;
%           end
%         end
    end
    
    setappdata(netcalMainWindow, 'project', project);
    printProjectInfo(project);
    updateProjectTree();
  end
  
  %------------------------------------------------------------------------
  function sortMethod(~, ~, ~, mode)
    project = getappdata(netcalMainWindow, 'project');
    project = labelsCheck(project);
    prevSelection = projectTree.SelectedNodes;
    % Capture scrollbar position
    jobjs = projectTree.getJavaObjects;
    vp = jobjs.jScrollPane.getViewport;
    vpp = vp.getViewPosition;

    namesList = cell(length(projectTree.Root.Children), 1);
    labelsList = cell(length(projectTree.Root.Children), 1);
    for i = 1:length(projectTree.Root.Children)
      namesList{i} = project.experiments{i};
      if(isempty(project.labels{i}))
        labelsList{i} = 'zzzz';
      else
        labelsList{i} = project.labels{i};
      end
    end
    
    switch mode
      case 'name'
        [~, newOrder] = sort(upper(namesList));
      case 'nameInverse'
        [~, newOrder] = sort(upper(namesList));
        newOrder = newOrder(end:-1:1);
      case 'label'
        [~, newOrder] = sort(upper(labelsList));
      case 'labelInverse'
        [~, newOrder] = sort(upper(labelsList));
        newOrder = newOrder(end:-1:1);
      case 'pairs'
        %answer = inputdlg('Pairs Keywords (two words)', 'Assign Pairs', [1 60], {'KEYWORD1 KEYWORD2'});
        answer = inputdlg('Pairs Keywords (two words)', 'Assign Pairs', [1 60], {'BASAL BIC'});
        words = strsplit(answer{1});
        if(length(words) ~= 2)
          logMsg(sprintf('Two words expected. Found %d instead', length(words)), 'e');
          return;
        end
        namesList = strtrim(upper(namesList));
        uwords = upper(words);
        newOrder = [];
        for it1  = 1:length(namesList)
          if(strfind(namesList{it1}, uwords(1)))
            % Might have a pair
            tmpName = strrep(namesList{it1}, uwords(1), uwords(2));
            pairIdx = find(strcmp(namesList, tmpName));
            if(~isempty(pairIdx))
              logMsg(sprintf('Pair found (%s/%s)', namesList{it1}, namesList{pairIdx(1)}));
              newOrder = [newOrder; it1; pairIdx(1)];
            end
          end
        end
        logMsg(sprintf('Found %d pairs', length(newOrder)/2));
        unpaired = setdiff(1:length(namesList), newOrder);
        newOrder = [newOrder; unpaired(:)];
    end
    
    %%% The actual reorder
    childrenList = projectTree.Root.Children;
    childrenList = childrenList(newOrder);
    % Update their names
    for i = 1:length(childrenList)
      childrenList(i).Name = sprintf('%3.d. %s', i, childrenList(i).TooltipString);
    end
    
    % Keep the tree invisible
    projectTree.Visible = 'off';
    set(childrenList, 'Parent', projectTree.Root);
    projectTree.Visible = 'on';

    reassignExperimentsToProject(projectTree);
    project.currentExperiment = find(newOrder == project.currentExperiment);
    

    prevSelectionNames = arrayfun(@(x)x.UserData{1}, prevSelection, 'UniformOutput', false);
    allNames = arrayfun(@(x)x.UserData{1}, childrenList, 'UniformOutput', false);
    try
      newList = cellfun(@(x)find(strcmp(x, allNames)), prevSelectionNames);
    catch
    end
    projectTree.SelectedNodes = childrenList(newList);
                          
    setappdata(netcalMainWindow, 'project', project);
    %updateProjectTree();
    
    % Get old scrollbar position
    jobjs = projectTree.getJavaObjects;
    vp = jobjs.jScrollPane.getViewport;
    vp.setViewPosition(vpp);
  end
  
  %------------------------------------------------------------------------
  function renameMethod(~, ~, handle)
    project = getappdata(netcalMainWindow, 'project');
    success = 0;
    for i = 1:length(handle.SelectedNodes)
      experimentName = handle.SelectedNodes(i).UserData{1};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      success = success + menuExperimentRename(experiment);
    end
    if(success > 0)
      updateProjectTree();
    end
  end
  
  %------------------------------------------------------------------------
  function deleteMethod(~, ~, handle)
    project = getappdata(netcalMainWindow, 'project');
    success = 0;
    namesToDelete = {};
    for i = 1:length(handle.SelectedNodes)
      namesToDelete{end+1} = handle.SelectedNodes(i).UserData{1};
    end
    for i = 1:length(namesToDelete)
      newObject.Label = namesToDelete{i};
      success = success + menuExperimentDelete(newObject);
    end
    if(success > 0)
      updateProjectTree();
    end
  end
  
  %------------------------------------------------------------------------
  function assignLabelMethod(~, ~, handle, type)
    if(isempty(handle.SelectedNodes))
      return;
    end
    success = 0;
    if(isempty(handle.SelectedNodes(1).UserData{2}))
      handle.SelectedNodes(1).UserData{2} = ' ';
    end
    switch type
      case 'assign'
        answer = inputdlg('Label list (comma separated)', 'Assign Label set', [1 60], {handle.SelectedNodes(1).UserData{2}});
      case 'add'
        answer = inputdlg('Label list (comma separated)', 'Add Label set', [1 60], {''});
      case 'remove'
        answer = inputdlg('Label list (comma separated)', 'Remove label set', [1 60], {handle.SelectedNodes(1).UserData{2}});
    end
    if(isempty(answer))
      return;
    end
    answer{1} = strtrim(answer{1});

    for i = 1:length(handle.SelectedNodes)
      success = success + menuExperimentAssignLabel(handle.SelectedNodes, type, answer{1});
    end
  end
  
  %------------------------------------------------------------------------
  function changeInfoMethod(~, ~, handle)
    project = getappdata(netcalMainWindow, 'project');
    success = false;
    for i = 1:length(handle.SelectedNodes)
      experimentName = handle.SelectedNodes(i).UserData{1};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      if(isfield(experiment, 'metadata') && isfield(experiment.metadata, 'info'))
        currentInfo = experiment.metadata.info;
      else
        currentInfo= '';
      end
      % Turn <br/> into \n and strip all html
      htmlPattern = '<[^>]*>';
      infoText = regexprep(currentInfo, '<br/>', '\n');
      infoText = regexprep(infoText, htmlPattern, '');
      answer = inputdlg(['Info for experiment: ' experimentName],...
             'Change experiment info', [5 60], {infoText});
      if(~isempty(answer))
        newInfoText = answer{1};
        % Get back to html
        newStr = '<html>';
        for k = 1:(size(newInfoText,1)-1)
          newStr = [newStr, newInfoText(k,:), '<br/>'];
        end
        newStr = [newStr, newInfoText(end,:), '</html>'];
        experiment.metadata.info = newStr;
        saveExperiment(experiment, 'verbose', false);
        success = true;
      end
    end
    if(success > 0)
      printSavedExperimentInfo();
    end
  end

  %------------------------------------------------------------------------
  function cloneMethod(~, ~, handle)
    project = getappdata(netcalMainWindow, 'project');
    success = 0;
    for i = 1:length(handle.SelectedNodes)
      experimentName = handle.SelectedNodes(i).UserData{1};
      experimentFile = [project.folderFiles experimentName '.exp'];
      experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      success = success + menuExperimentDuplicate(experiment);
    end
    if(success > 0)
      updateProjectTree();
      project = getappdata(netcalMainWindow, 'project');
      saveProject(project, 'gui', netcalMainWindow);
    end
  end
end

%--------------------------------------------------------------------------
function project = addNewExperimentNode(experiment, project, varargin)
  if(nargin >= 3)
    oldName = varargin{1};
  else
    oldName = [];
  end
  if(nargin >= 4)
    newTag = varargin{2};
  else
    newTag = [];
  end
  newNumber = numel(project.experiments)+1;
  project.experiments{newNumber} = experiment.name;
  if(~isfield(project, 'checkedExperiments'))
    project.checkedExperiments = false(size(project.experiments));
  else  
    project.checkedExperiments = [project.checkedExperiments(:); false];
  end
  if(~isempty(oldName))
    project.labels{newNumber} = project.labels{strcmp(oldName, project.experiments)};
  else
    project.labels{newNumber} = [];
  end
  if(~isempty(newTag))
    project.labels{newNumber} = newTag;
  end
  % Create the new node
  fullName = [experiment.name ' (' project.labels{newNumber} ')'];
  groupNode = uiextras.jTree.CheckboxTreeNode('Name', sprintf('%3.d. %s', newNumber, fullName), ...
                                              'TooltipString', experiment.name, ...
                                              'Parent', projectTree.Root, ...
                                              'Checked', false, ...
                                              'UserData', {project.experiments{newNumber}, project.labels{newNumber}, project.checkedExperiments(newNumber)});
  groupNode.Parent.Children; % WEIRD HACK FOR COMPTABILITY REASON IN MATLAB < 2017
  set(groupNode, 'UIContextMenu', projectTreeContextMenu)
end

%--------------------------------------------------------------------------
function project = removeExperimentNode(experimentName, project)
  currentNumber = find(strcmp(experimentName, project.experiments));
  project.experiments(currentNumber) = [];
  project.checkedExperiments(currentNumber) = [];
  project.labels(currentNumber) = [];
 
  curNode = projectTree.Root.Children(currentNumber);
  delete(curNode);
end

%--------------------------------------------------------------------------
function list = pipelineFuctionList()
  
  fileList = rdir([appFolder filesep 'internal' filesep, '**', filesep, '*.*'],...
    'regexp(lower(name), ''(\.m)$'')');
  if(DEVELOPMENT)
    fileListDev = rdir([appFolder filesep 'development' filesep 'internal' filesep, '**', filesep, '*.*'],...
      'regexp(lower(name), ''(\.m)$'')');
    fileList = [fileList; fileListDev];
  end
  list = {};
  for i = 1:length(fileList)
    [functionName, parametersClass, functionHandle, requiredFields, producedFields, parentGroups, functionType, helpTooltip]  = getPipelineParameters(fileList(i).name);
    if(isempty(functionName))
      continue;
    end
    try
      if(~isempty(parametersClass))
        list{end+1} = {functionName, functionHandle, eval(parametersClass), requiredFields, producedFields, parentGroups, functionType, helpTooltip};
      else
        list{end+1} = {functionName, functionHandle, [], requiredFields, producedFields, parentGroups, functionType, helpTooltip};
      end
    catch ME
      try
        logMsg(sprintf('There was a problem loading function %s', functionName), netcalMainWindow, 'w');
      catch
      end
      logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), netcalMainWindow, 'w');
    end
  end
  % Now let's add user functions
  fileList = rdir([appFolder filesep 'plugins' filesep 'pipeline' filesep, '**', filesep, '*.*'],...
                  'regexp(lower(name), ''(\.m)$'')');
  for i = 1:length(fileList)
    [functionName, parametersClass, functionHandle, requiredFields, producedFields, parentGroups, functionType, helpTooltip]  = getPipelineParameters(fileList(i).name);
    if(isempty(functionName))
      continue;
    end
    % Add the label plugins to any function there
    for j = 1:length(parentGroups)
      parentGroups{j} = ['plugins: ' parentGroups{j}];
    end
    try
      if(~isempty(parametersClass))
        list{end+1} = {functionName, functionHandle, eval(parametersClass), requiredFields, producedFields, parentGroups, functionType, helpTooltip};
      else
        list{end+1} = {functionName, functionHandle, [], requiredFields, producedFields, parentGroups, functionType, helpTooltip};
      end
    catch ME
      try
        logMsg(sprintf('There was a problem loading function %s', functionName), netcalMainWindow, 'w');
      catch
      end
      logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), netcalMainWindow, 'w');
    end
  end
  
  % Now let's sort the list by the parent (alphabetically)
  %parentNameList = cellfun(@(x)x{6}{1}, list, 'UniformOutput', false);
  parentNameList = cellfun(@(x)x{1}, list, 'UniformOutput', false);
 
  fullList = [parentNameList(:), parentNameList(:)];
  [~, idx] = sortrows(fullList, [1, 2]);
  list = list(idx);
  %cellfun(@(x)x{1}, list, 'UniformOutput', false)
end

%--------------------------------------------------------------------------
function nodeList = getAllChildren(node)
  if(~strcmp(node.Name, 'Root'))
    nodeList = node;
  else
    nodeList = [];
  end
  childrenList = node.Children;
  for i = 1:length(childrenList)
    nodeList = [nodeList, getAllChildren(childrenList(i))];
  end
end

%--------------------------------------------------------------------------
function createPipelineFunctions()
  functionList = pipelineFuctionList();

  pipelineFunctionsTree = TreeFunctionList('Parent',hs.pipelineFunctionListPanel);
  setappdata(netcalMainWindow, 'pipelineFunctionsTree', pipelineFunctionsTree);
  pipelineFunctionsTree.jCellRenderer.setFont(baseTreeFont);
  
  % The help button - not here, on the nodes
  %set(currentTree, 'UIContextMenu', pipelineTreeContextMenuRoot);
  
  % Create tree nodes
  for it = 1:length(functionList)
    opt = functionList{it}{3};
    if(~isempty(opt))
      opt = opt.setDefaults;
    end
    parentGroups = functionList{it}{6};
    % Look for possible parent group
    if(~isempty(parentGroups))
      nodeList = getAllChildren(pipelineFunctionsTree.Root);
      for it2 = 1:length(parentGroups)
        % Create the parent and assign it
        % If the parent has a colon, it's nested, check for the root and create if needed first
        splitName = strtrim(strsplit(parentGroups{it2}, ':'));
        % Go through all levels
        currentName = splitName{1};
        previousParent = pipelineFunctionsTree.Root;
        for it3 = 1:length(splitName)
          % Generate partial name
          if(it3 > 1)
            currentName = [currentName, ': ' splitName{it3}];
          end
          % Check if any node with the partial name exists
          parentFoundIdx = find(arrayfun(@(x,y) strcmpi(x.TooltipString, currentName), nodeList));
          if(~isempty(parentFoundIdx))
            % If I found a parent, return it
            if(length(parentFoundIdx) > 1)
              for it4 = 1:length(parentFoundIdx)
                logMsg(sprintf('Warning! Multiple parents found while creating the pipeline function list for: %s', functionList{it}{1}), 'w');
              end
              previousParent = nodeList(parentFoundIdx(1));
            else
              previousParent = nodeList(parentFoundIdx);
            end
          else
            % Else, create and attach it to the previous parent
            previousParent = uiextras.jTree.TreeNode('Name', splitName{it3}, ...
                            'Parent', previousParent, 'TooltipString', currentName);
          end
        end
        % Ok, once here, all parents should exist, create the function node
        rr = uiextras.jTree.TreeNode('Name', strtrim(functionList{it}{1}), ...
                                     'Parent', previousParent, ...
                                     'TooltipString', functionList{it}{1}, ...
                                     'UserData', {[], opt, functionList{it}{2}, functionList{it}{4}, functionList{it}{5}, functionList{it}{7}, functionList{it}{8}});
        pipelineTreeContextMenuRoot = uicontextmenu('Parent', netcalMainWindow);
        uimenu(pipelineTreeContextMenuRoot, 'Label', 'Add', 'Callback', {@pipelineFunctionAdd, rr});
        uimenu(pipelineTreeContextMenuRoot, 'Label', 'Help', 'Callback', {@pipelineFunctionHelp, functionList{it}{3}});
        set(rr, 'UIContextMenu', pipelineTreeContextMenuRoot);
        switch functionList{it}{7}
          case 'projexp'
            colName = 'purple';
          case 'experiment'
            colName = 'blue';
          case 'project'
            colName = 'orange';
          case 'projANDexp'
            colName = 'orange';
          case 'projexpDebug'
            colName = 'red';
          case 'experimentDebug'
            colName = 'red';
          case 'projectDebug'
            colName = 'red';
        end
        rr.Name = strrep(rr.Name, ' ', '&nbsp;');
        set(rr, 'Name', sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(get(rr, 'Name'), '<[^>]*>', '')));
        rr.Parent.Children; % WEIRD HACK FOR COMPTABILITY REASON IN MATLAB < 2017
      end
    else
      % If there are no parents (weird case)
      rr = uiextras.jTree.TreeNode('Name', strtrim(functionList{it}{1}), ...
                                   'Parent', pipelineFunctionsTree.Root, ...
                                   'TooltipString', functionList{it}{1}, ...
                                   'UserData', {[], opt, functionList{it}{2}, functionList{it}{4}, functionList{it}{5}, [], functionList{it}{8}});
      pipelineTreeContextMenuRoot = uicontextmenu('Parent', netcalMainWindow);
      uimenu(pipelineTreeContextMenuRoot, 'Label', 'Add', 'Callback', {@pipelineFunctionAdd, functionList{it}{3}});
      uimenu(pipelineTreeContextMenuRoot, 'Label', 'Help', 'Callback', {@pipelineFunctionHelp, functionList{it}{3}});
      set(rr, 'UIContextMenu', pipelineTreeContextMenuRoot);
      switch functionList{it}{7}
        case 'projexp'
          colName = 'purple';
        case 'experiment'
          colName = 'blue';
        case 'project'
          colName = 'orange';
        case 'projANDexp'
          colName = 'orange';
        case 'projexpDebug'
          colName = 'red';
        case 'experimentDebug'
          colName = 'red';
        case 'projectDebug'
          colName = 'red';
      end
      rr.Name = strrep(rr.Name, ' ', '&nbsp;');
      set(rr, 'Name', sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(get(rr, 'Name'), '<[^>]*>', '')));
      rr.Parent.Children; % WEIRD HACK FOR COMPTABILITY REASON IN MATLAB < 2017
    end
  end
  
  pipelineFunctionsTree.RootVisible = false;
  pipelineFunctionsTree.DndEnabled = true;
  %currentTree.SelectionType = 'discontiguous';
  pipelineFunctionsTree.SelectionType = 'single';
  %currentTree.FontSize = textFontSize;
  pipelineFunctionsTree.SelectionChangeFcn = @selectedMethodAvailableFunction;
  

  pipelineTree = CheckboxTreePipeline('Parent',hs.pipelinePanel);
  if(guiImprovements)
    pipelineTreeListener = addlistener(pipelineTree.getJavaObjects.jTree, 'Keypressed', @clickPipeline);
  end
  pipelineTree.jCellRenderer.setFont(baseTreeFont);

  %pipelineTree.FontName = 'Courier New';
  %pipelineTree.FontSize = textFontSize;

  % Create tree nodes
  pipelineTree.RootVisible = false;
  pipelineTree.DndEnabled = true;
  pipelineTree.SelectionType = 'discontiguous';
  if(guiImprovements)
    pipelineTree.ButtonDownFcn = @checkedHack;
  end
  
  pipelineTree.CheckboxClickedCallback = @checkedMethodPipeline;
  pipelineTree.UserData = {};  
  %currentPipelineTree.FontSize = textFontSize;
  
  
  pipelineTree.SelectionChangeFcn = @selectedMethodPipeline;
  optionsWindow([], 'parent', hs.pipelineOptionsPanel);
    
  pipelineFunctionsTree.NodeDroppedCallback = @(s,e)pipelineTreeDnDCallback(s,e);
  pipelineTree.NodeDroppedCallback = @(s,e)pipelineTreeDnDCallback(s,e);
  
  % Now let's reorder the tree
  rootNames = arrayfun(@(x)x.Name, pipelineFunctionsTree.Root.Children, 'UniformOutput', false);
  [~, sorted] = sort(rootNames);
  nodesOrdered = pipelineFunctionsTree.Root.Children(sorted);
  set(nodesOrdered, 'Parent', pipelineFunctionsTree.Root);
  % Now let's reorder the children
  % This bit here sorts children, first those with children and then by name
  pipelineSortChildren(pipelineFunctionsTree.Root);
  
  setappdata(netcalMainWindow, 'Tree', pipelineFunctionsTree);
  setappdata(netcalMainWindow, 'pipelineTree', pipelineTree);
end

%--------------------------------------------------------------------------
function parent = pipelineSortChildren(parent)
  if(isempty(parent.Children))
    return;
  end
  for itt = 1:length(parent.Children)
    curNode = parent.Children(itt);
    subChildrenNames = arrayfun(@(x)x.Name, curNode.Children, 'UniformOutput', false);
    subChildrenNames = strrep(regexprep(subChildrenNames, '<[^>]*>', ''), '&nbsp;', ' ');
    subChildrenChildren  = arrayfun(@(x)length(x.Children), curNode.Children, 'UniformOutput', false);
    [~, sorted1] = sort([subChildrenChildren{:}], 'descend');
    [~, sorted2] = sort(subChildrenNames);
    preSorted2 = arrayfun(@(x)find(x==sorted2), 1:length(sorted2));
    sorted1 = [subChildrenChildren{:}];
    newmat = [~~sorted1(:), preSorted2(:)];
    [~, sorted] = sortrows(newmat, [-1, 2]);
    nodesOrdered = curNode.Children(sorted);
    set(nodesOrdered, 'Parent', curNode);
  end
  % Now that these nodes are ordered, order the children
  for itt = 1:length(parent.Children)
    curNode = parent.Children(itt);
    pipelineSortChildren(curNode);
  end
end

%--------------------------------------------------------------------------
function pipelineFunctionAdd(~, ~, caller)
  s = pipelineTree;
  e = struct;
  e.Source = caller;
  e.Target = pipelineTree.Root;
  e.DropAction = 'move';
  e.dragType = 'functionToPipeline';
  %pipelineTree.onNodeDND(s, e);

  opt = caller.UserData{2};
  rr = uiextras.jTree.CheckboxTreeNode('Name', sprintf('%3.d. %s', length(pipelineTree.Root.Children)+1, caller.Name), ...
                              'Parent', pipelineTree.Root, ...
                              'TooltipString', caller.Name, ...
                              'Checked', false, ...
                              'UserData', caller.UserData);
      if(~isempty(caller.UserData{6}))
        switch caller.UserData{6}
          case 'projexp'
            colName = 'purple';
          case 'experiment'
            colName = 'blue';
          case 'project'
            colName = 'orange';
          case 'projexpDebug'
            colName = 'red';
          case 'experimentDebug'
            colName = 'red';
          case 'projectDebug'
            colName = 'red';
          otherwise
            colName = 'black';
        end
      else
        colName = 'black';
      end
      rr.Name = strrep(rr.Name, ' ', '&nbsp;');
      set(rr, 'Name', sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(get(rr, 'Name'), '<[^>]*>', '')));
      rr.Parent.Children; % WEIRD HACK FOR COMPTABILITY REASON IN MATLAB < 2017 - This is the Schroedinger pipeline, if I don't query the children they don't get saved
end

%--------------------------------------------------------------------------
function pipelineFunctionHelp(~, ~, caller)

  caller = class(caller);

  % Firs thing is to know who is selected
  functionFile = [caller, '.m'];
  
  btHelp_CallbackStandalone(functionFile);
  
  function btHelp_CallbackStandalone(classFile)
    % Delete any previous help function
    %delete(findall(0, '-depth',1, 'Tag','fpropertiesGUIhelp'));
    helpFig = findall(0, '-depth',1, 'Tag','fpropertiesGUIhelpPipeline');
    if(~isempty(helpFig))
      clf(helpFig);
    else
      helpFig = figure('NumberTitle','off', ...
                  'Name', 'Help', ...
                  'Units','pixel', ...
                  'Menu','none', ...
                  'Toolbar','none', ...
                  'Tag','fpropertiesGUIhelpPipeline', ...
                  'Visible','off');
      helpFig.Position = setFigurePosition(netcalMainWindow, 'width', 500, 'height', 500);
    end

    %helpPanel = MarkdownPanel('Parent', helpFig);
    helpText = generateAutomaticHelpFile(classFile);

    helpPanel = newMarkdownPanel24(helpFig, helpText);
    helpFig.Visible = 'on';

   timerFcn = @(s,e)set(helpPanel, 'Content', char(helpPanel.Content));
    htimer = timer( ...
        'Period',        1, ...
        'BusyMode',      'drop', ...
        'TimerFcn',      timerFcn, ...
        'ExecutionMode', 'fixedRate');

    % Destroy the timer when the panel is destroyed

    L = addlistener(helpPanel, 'ObjectBeingDestroyed', @timerCallback);
    setappdata(helpFig, 'Timer', L);

    % Start the refresh timer
    start(htimer)
     function timerCallback(~, ~)
        stop(htimer);
        delete(htimer);
     end

  end
  
end

%------------------------------------------------------------------------
function DropOk = pipelineTreeDnDCallback(s, e)
  e.Source
  e.Target
  for it = 1:length(e.Source)
    if(isvalid(e.Source(it)) && isa(e.Source(it).Tree, 'CheckboxTreePipeline'))
      enew.Nodes = e.Source(it).Tree.SelectedNodes;
      selectedMethodPipeline(e.Source(it).Tree, enew);
    end
    if(isvalid(e.Target) && isa(e.Target.Tree, 'CheckboxTreePipeline'))
      enew.Nodes = e.Target.Tree.SelectedNodes;
      selectedMethodPipeline(e.Target.Tree, enew);
    end
  end
  DropOk = true;
end


%--------------------------------------------------------------------------
function clickPipeline(hObject, eData)
  if(guiImprovements)
    if(strcmp(eData.getKeyText(eData.getKeyCode()),'Delete') | strcmp(eData.getKeyText(eData.getKeyCode()),'Backspace'))
      % Delete the current function
      if(isempty(pipelineTree.SelectedNodes))
        return;
      end
      prevNode = find(pipelineTree.Root.Children == pipelineTree.SelectedNodes(1))-1;
      if(~isempty(prevNode) && prevNode > 1)
        newSelNode = pipelineTree.Root.Children(prevNode);
      end
      delete(pipelineTree.SelectedNodes);
      if(~isempty(prevNode) && prevNode > 1)
        pipelineTree.SelectedNodes = newSelNode;
        e.Nodes = newSelNode;
      end

      selectedMethodPipeline(pipelineTree, e);
    end
  end
end

%------------------------------------------------------------------------
function selectedMethodPipeline(h, e)
  parent = hs.pipelineOptionsPanel;

  updateActiveNodeParams(h);
  project = getappdata(netcalMainWindow, 'project');
  if(length(e.Nodes) > 1 || isempty(e.Nodes))
%     if(currentTree == 2)
%       optionsWindow([], 'parent', parent, 'parentType', 'secondary', 'project', project);
%     else
      optionsWindow([], 'parent', parent, 'project', project);
%     end
    activeNode = [];
    return;
  end

  if(isfield(project, 'checkedExperiments') && sum(project.checkedExperiments) >= 1)
    checkedExperiments = find(project.checkedExperiments);
    experimentName = project.experiments{checkedExperiments(1)};
    experimentFile = [project.folderFiles experimentName '.exp'];
    optionsWindow(e.Nodes(1).UserData{2}, 'parent', parent, 'experiment', experimentFile, 'project', project);
  else
    optionsWindow(e.Nodes(1).UserData{2}, 'parent', parent, 'project', project);
  end
  
  activeNode = e.Nodes(1).UserData{1};
end

%------------------------------------------------------------------------
function checkedMethodPipeline(h, e)
  % For now don't really need to do anything with checked experiments

end

%------------------------------------------------------------------------
function selectedMethodAvailableFunction(h, e)
  curNode = h.SelectedNodes;
  if(length(curNode) == 1)
    curNode = curNode(1);
    if(isempty(curNode.UserData) || length(curNode.UserData) < 7)
      logMessage(hs.pipelineFunctionListInfoPanelEditBox, 'clear');
      logMessage(hs.pipelineFunctionListInfoPanelEditBox, 'No Function selected');
    else
      %jpan = findjobj(hs.infoPanel);
      jpan = findjobj(hs.pipelineFunctionListInfoPanel);
      vp = jpan.getViewport;
      vpp = vp.getViewPosition;
      logMessage(hs.pipelineFunctionListInfoPanelEditBox, 'clear');
      %logMessage(hs.pipelineFunctionListInfoPanelEditBox, sprintf('%s (%s .m)', curNode.Name, curNode.UserData{3}));
      logMessage(hs.pipelineFunctionListInfoPanelEditBox, curNode.Name);
      logMessage(hs.pipelineFunctionListInfoPanelEditBox, sprintf('(%s.m)', curNode.UserData{3}));
      logMessage(hs.pipelineFunctionListInfoPanelEditBox, '-------');
      for it = 1:length(curNode.UserData{7})
        logMessage(hs.pipelineFunctionListInfoPanelEditBox, curNode.UserData{7}{it});
      end
      jpan = findjobj(hs.pipelineFunctionListInfoPanel);
      vp = jpan.getViewport;
      vp.setViewPosition(vpp);
      vp.updateUI();
    end
  else
    logMessage(hs.pipelineFunctionListInfoPanelEditBox, 'clear');
    logMessage(hs.pipelineFunctionListInfoPanelEditBox, 'No Function selected');
  end
end

%------------------------------------------------------------------------
function updateActiveNodeParams(h, selectedNodes)
  if(nargin >= 2)
    if(~isempty(selectedNodes))
      activeNode = selectedNodes(1);
    else
      activeNode = [];
    end
  end
  if(~isempty(activeNode))

    curClassParams = getappdata(netcalMainWindow, 'curClassParams');

    childrenList = h.Root.Children;
    % Update the node options values
    for i = 1:length(childrenList)
      if(childrenList(i).UserData{1} == activeNode)
        if(~isempty(curClassParams))
          childrenList(i).UserData{2} = curClassParams;
        end
        break;
      end
    end
  end
end

%------------------------------------------------------------------------
function success = pipelineCheck(~, ~, verbose)
  
  % First update the current node
  updateActiveNodeParams(pipelineTree);
  
  if(nargin < 4)
    verbose = true;
  end
  success = false;
  % Get available fields from the first checked experiment
  if(verbose)
    logMsgHeader('Checking pipeline consistency', 'start');
  end
  project = getappdata(netcalMainWindow, 'project');
  if(isempty(project))
    logMsg('No project found', 'e');
    return;
  end
  checkedExperiments = find(project.checkedExperiments);
  if(isempty(checkedExperiments))
    logMsg('No checked experiments found', 'e');
    logMsgHeader('Done!', 'finish');
    return;
  end
  experimentName = project.experiments{checkedExperiments(1)};
  experimentFile = [project.folderFiles experimentName '.exp'];
  experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project, 'pbar', 0);
  %groupNames = getExperimentGroupsNames(experiment);
  availableFields = fieldnames(experiment);

  % Now the check
  if(isempty(pipelineTree.CheckedNodes))
    logMsg('No checked functions found in the pipeline', 'e');
    logMsgHeader('Done!', 'finish');
    return;
  end
  if(length(pipelineTree.CheckedNodes) == 1 && strcmp(pipelineTree.CheckedNodes(1).Name, 'Root'))
    fullPipeline = true;
  else
    fullPipeline = false;
  end
  functionList = pipelineTree.Root.Children;
  for i = 1:length(functionList)
    if(fullPipeline || any(pipelineTree.CheckedNodes == functionList(i)))
      requiredFields = functionList(i).UserData{4}';
      newFields = functionList(i).UserData{5}';
      
      for j = 1:length(requiredFields)
        if(~any(strcmp(requiredFields{j}, availableFields)))
          logMsg(sprintf('Required field %s for function %s not found in the experiment %s', requiredFields{j}, functionList(i).UserData{3}, experimentName), 'e');
          logMsgHeader('Done!', 'finish');
          return;
        end
      end
      % If all required fields checked out, add the new fields to the list
      for j = 1:length(newFields)
        availableFields{end+1} = newFields{j};
      end
    end
  end
  if(verbose)
    logMsg('Everything appears to be ok in the pipeline');
    logMsgHeader('Done!', 'finish');
  end
  success = true;
end

%------------------------------------------------------------------------
%function pipelineSort(currentTree)
%  sortNodeChildren(currentTree.Root);
%end

%------------------------------------------------------------------------
function sortNodeChildren(node)
  childrenList = node.Children;
  for it = 1:length(childrenList)
    sortNodeChildren(childrenList(it));
  end
  if(~isempty(childrenList))
    newList = sortThisList(childrenList);
    for it = 1:length(newList)
      newList(it).Parent = node;
    end
  end
end

%--------------------------------------------------------------------------
function newList = sortThisList(nodeList)
  oldList = nodeList;
  newList = [];
  while(~isempty(oldList))
    nodeInserted = false;
    for j = 1:length(oldList)
      if(nodeInserted)
        break;
      end
      if(isempty(oldList(j).UserData))
        nodeInserted = true;
        newList = [newList, oldList(j)];
        oldList(j) = [];
      else
        availableFields = oldList(j).UserData{5};
        for k = 1:length(newList)
          if(nodeInserted)
            break;
          end
          requiredFields = newList(k).UserData{4};
          for l = 1:length(requiredFields)
            if(nodeInserted)
              break;
            end
            if(any(strcmp(requiredFields{j}, availableFields)))
              nodeInserted = true;
              newList = [newList(1:(k-1)), oldList(j), newList(k:end)];
              oldList(j) = [];
            end
          end
        end
        if(~nodeInserted)
          nodeInserted = true;
          newList = [newList, oldList(j)];
          oldList(j) = [];
        end
      end
    end
  end
  
end

%--------------------------------------------------------------------------
function pipelineRun(~, ~, parallelMode)
  if(nargin < 3)
    parallelMode = false;
  end
  
  % First update the current node
  updateActiveNodeParams(pipelineTree);
  
  % First check its consistency
  if(~pipelineCheck([], [], false))
    return;
  end

  project = getappdata(netcalMainWindow, 'project');
  
  % Update the checked experiment list - to avoi the weird clicking bug
  project.checkedExperiments = arrayfun(@(x)x.Checked, projectTree.Root.Children);
  for it = 1:length(projectTree.Root.Children)
    projectTree.Root.Children(it).UserData{3} = logical(project.checkedExperiments(it));
  end
    
  checkedExperiments = find(project.checkedExperiments);
  if(isempty(checkedExperiments))
    logMsg('No checked experiments found', 'e');
    logMsgHeader('Done!', 'finish');
    return;
  end
  
  % Let's get the function list
  if(isempty(pipelineTree.CheckedNodes))
    logMsg('No checked functions found in the pipeline', 'e');
    logMsgHeader('Done!', 'finish');
    return;
  end
  if(length(pipelineTree.CheckedNodes) == 1 && strcmp(pipelineTree.CheckedNodes(1).Name, 'Root'))
    fullPipeline = true;
  else
    fullPipeline = false;
  end
  functionList = pipelineTree.Root.Children;
  functionHandleList = {};
  optionsList = {};
  nodeList = {};
  modeList = {};
  colList = {};
  
  for i = 1:length(functionList)
    % First redo the names
    functionList(i).Name = sprintf('%3.d. %s', i, functionList(i).TooltipString);
    if(length(functionList(i).UserData) > 5 && ~isempty(functionList(i).UserData{6}))
      switch functionList(i).UserData{6}
        case 'projexp'
          colName = 'purple';
        case 'experiment'
          colName = 'blue';
        case 'project'
          colName = 'orange';
        case 'projANDexp'
          colName = 'orange';
        case 'projexpDebug'
          colName = 'red';
        case 'experimentDebug'
          colName = 'red';
        case 'projectDebug'
          colName = 'red';
        otherwise
          colName = 'black';
      end
      functionList(i).Name = sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(functionList(i).Name, '<[^>]*>', ''));
    end                   
    if(fullPipeline || any(pipelineTree.CheckedNodes == functionList(i)))
      functionHandleList{end+1} = functionList(i).UserData{3};
      optionsList{end+1} = functionList(i).UserData{2};
      nodeList{end+1} = functionList(i);
      modeList{end+1} = functionList(i).UserData{6};
      if(~isempty(modeList{end}))
        switch modeList{end}
          case 'projexp'
            colName = 'purple';
          case 'experiment'
            colName = 'blue';
          case 'project'
            colName = 'orange';
          case 'projANDexp'
            colName = 'orange';
          case 'projexpDebug'
            colName = 'red';
          case 'experimentDebug'
            colName = 'red';
          case 'projectDebug'
            colName = 'red';
          otherwise
            colName = 'black';
        end
      else
        colName = 'black';
      end
      colList{end+1} = colName;
    end
  end
  
  %%% The actual RUN
  if(~parallelMode)
    logMsgHeader(sprintf('Running pipeline on %d experiments', sum(project.checkedExperiments)), 'start');
    ncbar('Processing functions', 'Processing experiments', '');
    % For each funciton in the list, do the analysis
    for f = 1:length(functionHandleList)
      ncbar.setCurrentBar(1);
      ncbar.setCurrentBarName(sprintf('Processing %s (%d/%d)', functionHandleList{f}, f, length(functionHandleList)));
      ncbar.update((f-1)/length(functionHandleList), 'force');
      
      nodeList{f}.Name = sprintf('<html><font color="red">%s</font></html>', regexprep(nodeList{f}.Name, '<[^>]*>', ''));
      analysisFunction = functionHandleList{f};
      logMsg(sprintf('%d. Running function %s', f, analysisFunction));

      if(isempty(modeList{f}))
        logMsg(sprintf('Function mode not found. Assuming experiment'), 'w');
        modeList{f} = 'experiment';
      elseif(strcmp(modeList{f}, 'projexp') || strcmp(modeList{f}, 'projexpDebug'))
        if(~isprop(optionsList{f}, 'pipelineMode'))
          logMsg(sprintf('Function pipelineMode undefined. Assuming experiment'), 'w');
          curMode = 'experiment';
        else
          curMode = optionsList{f}.pipelineMode;
        end
        if(isempty(curMode) || ~ischar(curMode))
          logMsg(sprintf('Function pipelineMode undefined. Assuming experiment'), 'w');
          modeList{f} = 'experiment';
        else
          switch curMode
            case {'project', 'projectDebug'}
              modeList{f} = 'project';
            case {'experiment', 'experimentDebug'}
              modeList{f} = 'experiment';
            otherwise
              logMsg(sprintf('Function pipelineMode undefined. Assuming experiment'), 'w');
              modeList{f} = 'experiment';
          end
        end
      end
      % Check if there are options to pass
      if(~isempty(optionsList{f}))
        optionsClassCurrent = optionsList{f};
        origOpClass = class(optionsClassCurrent);
        tmpObj = eval(origOpClass);
        tmpObj = tmpObj.setDefaults();
        allProps = properties(tmpObj);
        for it = 1:length(allProps)
          if(~isprop(optionsClassCurrent, allProps{it}))
            logMsg(sprintf('Mismatch in option set (%s) for function %s. Try removing and adding it again from the function list', allProps{it}, analysisFunction), 'e');
            ncbar.close();
            return;
          elseif(isstruct(tmpObj.(allProps{it})))
            allFields = fieldnames(tmpObj.(allProps{it}));
            for it2 = 1:length(allFields)
              if(~isfield(optionsClassCurrent.(allProps{it}), allFields{it2}))
                logMsg(sprintf('Mismatch in option set (%s.%s) for function %s. I''ll try to add it with the default value, but try removing and adding it again from the function list', allProps{it}, allFields{it2}, analysisFunction), 'e');
                optionsClassCurrent.(allProps{it}).(allFields{it2}) = tmpObj.(allProps{it}).(allFields{it2});
              end
            end
          end
        end
        if(isprop(optionsClassCurrent, 'verbose'))
          verboseVar = optionsClassCurrent.verbose;
        else
          verboseVar = false;
        end
        optarg = {optionsClassCurrent, 'pbar', 3, 'verbose', verboseVar};
      else
        optarg = {'pbar', 3, 'verbose', false};
      end
      switch modeList{f}
        case {'project', 'projectDebug'}
          ncbar.setCurrentBar(2);
          ncbar.setCurrentBarName('processing experiments');
          ncbar.setCurrentBar(3);
          % The actual run
          try
            project = feval(analysisFunction, project, optarg{:});
            if(~isempty(optionsList{f}))
              project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
            end
          catch ME
            logMsg(sprintf('Something went wrong while processing %s on the project', analysisFunction), 'e');
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
          end
          % Check for figure tiling
          if(~isempty(optionsList{f}))
            if(isa(optionsClassCurrent, 'plotBaseOptions'))
              try
                if(optionsClassCurrent.tileFigures)
                  autoArrangeFigures();
                end
              catch
              end
            elseif(isa(optionsClassCurrent, 'plotFigureOptions'))
              try
                %optionsClassCurrent.styleOptions
                if(optionsClassCurrent.styleOptions.tileFigures)
                  autoArrangeFigures();
                end
             catch
             end
            end
          end
        case {'experiment', 'experimentDebug', 'projANDexp'}
          for it = 1:length(checkedExperiments)
            experimentIndex = checkedExperiments(it);
            ncbar.setCurrentBar(2);
            ncbar.update((it-1)/length(checkedExperiments), 'force');
            infoMsg = sprintf('Processing %s (%d/%d)', project.experiments{experimentIndex}, it, length(checkedExperiments));
            ncbar.setCurrentBarName(infoMsg);
            
            % The actual run
            experimentName = project.experiments{experimentIndex};
            experimentFile = [project.folderFiles experimentName '.exp'];
            ncbar.setCurrentBar(3);
            try
              experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project, 'pbar', 3);
              oldExperiment = experiment; % Copy to check for changes
              
              if(strcmp(modeList{f}, 'projANDexp'))
                experiment = feval(analysisFunction, experiment, project, optarg{:});
              else
                experiment = feval(analysisFunction, experiment, optarg{:});
              end
              if(~isempty(optionsList{f}))
                experiment.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
                project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
              end
              % Save the experiment if there are changes
              if(~isequaln(oldExperiment, experiment))
                % First check if the option to save the experiment exists
                try
                  if(~isempty(optionsList{f}) && isa(optionsClassCurrent, 'plotFigureOptions') && ~optionsClassCurrent.saveOptions.saveExperiment)
                    logMsg('Skipping saving experiment');
                  else
                    saveExperiment(experiment, 'verbose', false, 'pbar', 3);
                  end
                catch
                  saveExperiment(experiment, 'verbose', false, 'pbar', 3);
                end
              end
            catch ME
              logMsg(sprintf('Something went wrong while processing %s on %s', analysisFunction, experimentName), 'e');
              logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
            end
            %executeExperimentFunctions(project, experimentIndex, functionHandleList, optionsList, 'pbar', p, 'verbose', false);
            ncbar.setCurrentBar(2);
            ncbar.update((it)/length(checkedExperiments), 'force'); 
            % Check for figure tiling
            if(~isempty(optionsList{f}))
              if(isa(optionsClassCurrent, 'plotBaseOptions'))
                try
                  if(optionsClassCurrent.tileFigures)
                    autoArrangeFigures();
                  end
                catch
                end
              elseif(isa(optionsClassCurrent, 'plotFigureOptions'))
                try
                  %optionsClassCurrent.styleOptions
                  if(optionsClassCurrent.styleOptions.tileFigures)
                    autoArrangeFigures();
                  end
               catch
                end
              elseif(isprop(optionsClassCurrent, 'tileFigures'))
                try
                  if(optionsClassCurrent.tileFigures)
                    autoArrangeFigures();
                  end
                catch
                end
              end
            end
          end
      end
%       % Check for figure tiling
%       if(~isempty(optionsList{f}))
%         if(isa(optionsClassCurrent, 'plotBaseOptions'))
%           try
%             if(optionsClassCurrent.tileFigures)
%               autoArrangeFigures();
%             end
%           catch
%           end
%         elseif(isa(optionsClassCurrent, 'plotFigureOptions'))
%           try
%             optionsClassCurrent.styleOptions
%             if(optionsClassCurrent.styleOptions.tileFigures)
%               autoArrangeFigures();
%             end
%          catch
%          end
%         end
%       end
      % Now the function is over. Next
      nodeList{f}.Name = sprintf('<html><font color="%s">%s</font></html>', colList{f}, regexprep(nodeList{f}.Name, '<[^>]*>', ''));
    end
    ncbar.close();
  else
    logMsgHeader(sprintf('Running parallel pipeline on %d experiments', sum(project.checkedExperiments)), 'start');
    ncbar('Processing functions', 'Processing experiments');
    % For each funciton in the list, do the analysis
    for f = 1:length(functionHandleList)
      ncbar.setCurrentBar(1);
      ncbar.setCurrentBarName(sprintf('Processing %s (%d/%d)', functionHandleList{f}, f, length(functionHandleList)));
      ncbar.update((f-1)/length(functionHandleList), 'force');
      
      nodeList{f}.Name = sprintf('<html><font color="red">%s</font></html>', regexprep(nodeList{f}.Name, '<[^>]*>', ''));
      analysisFunction = functionHandleList{f};
      logMsg(sprintf('Running function %s', analysisFunction));

      if(isempty(modeList{f}))
        logMsg(sprintf('Function mode not found. Assuming experiment'), 'w');
        modeList{f} = 'experiment';
      elseif(strcmp(modeList{f}, 'projexp') || strcmp(modeList{f}, 'projexpDebug'))
        if(~isprop(optionsList{f}, 'pipelineMode'))
          logMsg(sprintf('Function pipelineMode undefined. Assuming experiment'), 'w');
          curMode = 'experiment';
        else
          curMode = optionsList{f}.pipelineMode;
        end
        if(isempty(curMode) || ~ischar(curMode))
          logMsg(sprintf('Function pipelineMode undefined. Assuming experiment'), 'w');
          modeList{f} = 'experiment';
        else
          switch curMode
            case {'project', 'projectDebug'}
              modeList{f} = 'project';
            case {'experiment', 'experimentDebug'}
              modeList{f} = 'experiment';
            otherwise
              logMsg(sprintf('Function pipelineMode undefined. Assuming experiment'), 'w');
              modeList{f} = 'experiment';
          end
        end
      end
      switch modeList{f}
        % Project functions cannot be run on parallel for now
        case {'project', 'projectDebug'}
          % Check if there are options to pass
          if(~isempty(optionsList{f}))
            optionsClassCurrent = optionsList{f};
            optarg = {optionsClassCurrent, 'pbar', 2, 'verbose', false};
          else
            optarg = {'pbar', 2, 'verbose', false};
          end
          ncbar.setCurrentBar(2);
          ncbar.update(0, 'force');
          % The actual run
          try
            project = feval(analysisFunction, project, optarg{:});
            if(~isempty(optionsList{f}))
              project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
            end
          catch ME
            logMsg(sprintf('Something went wrong while processing %s on the project', analysisFunction), 'e');
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
          end
        case {'experiment', 'experimentDebug', 'projANDexp'}
          % Check if there are options to pass
          if(~isempty(optionsList{f}))
            optionsClassCurrent = optionsList{f};
            optarg = {optionsClassCurrent, 'pbar', 0, 'verbose', false};
          else
            optarg = {'pbar', 0, 'verbose', false};
          end
          cl = parcluster('local');
          ncbar.setCurrentBar(2);
          ncbar.update(0, 'force');
          infoMsg = sprintf('Processing experiments (%d)', length(checkedExperiments));
          ncbar.setCurrentBarName(infoMsg);
          numCompleted = 0;
          for it = 1:length(checkedExperiments)
            experimentIndex = checkedExperiments(it);
            
            % The actual run
            experimentName = project.experiments{experimentIndex};
            experimentFile = [project.folderFiles experimentName '.exp'];

            try
              experiment = loadExperiment(experimentFile, 'verbose', false, 'project', project, 'pbar', 3);
              if(strcmp(modeList{f}, 'projANDexp'))
                futures(it) = parfeval(str2func(analysisFunction), 1, experiment, project, optarg{:});
              else
                futures(it) = parfeval(str2func(analysisFunction), 1, experiment, optarg{:});
              end
              
            catch ME
              numCompleted = numCompleted + 1;
              logMsg(sprintf('Something went wrong while processing %s on %s', analysisFunction, experimentName), 'e');
              logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
            end
          end
          % Now wait for the functions to finish
          while numCompleted < length(checkedExperiments)
            ncbar.setBarName(sprintf('Processing experiments (%d/%d)', numCompleted, length(checkedExperiments)));
            [completedIdx, experiment] = fetchNext(futures);
            if(~isempty(optionsList{f}))
              experiment.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
              project.([class(optionsClassCurrent) 'Current']) = optionsClassCurrent;
            end
            saveExperiment(experiment, 'verbose', false, 'pbar', 0);
            
            numCompleted = numCompleted + 1;
            infoMsg = sprintf('Processed %s on %s (%d/%d)', functionHandleList{f}, project.experiments{checkedExperiments(completedIdx)}, numCompleted, length(checkedExperiments));
            logMsg(infoMsg);
            ncbar.update(numCompleted/length(checkedExperiments));
          end
      end
      % Now the function is over. Next
      nodeList{f}.Name = sprintf('<html><font color="%s">%s</font></html>', colList{f}, regexprep(nodeList{f}.Name, '<[^>]*>', ''));
    end
    ncbar.close();
  end
  logMsgHeader('Done!', 'finish');
end

%--------------------------------------------------------------------------
function menuProjectSave(~, ~)
%  netcalMainWindow = gcbf;
  ncbar.automatic('Saving project...');

  project = getappdata(netcalMainWindow, 'project');
  if(~isempty(project))
    saveProject(project, 'gui', netcalMainWindow);
  end
  % Save the project pipeline
  try
    savePipeline([], [], [project.folder filesep 'pipeline.json']);
  catch ME
    logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
  end
  ncbar.close();
end

%--------------------------------------------------------------------------
function savePipeline(~, ~, pipelineFile)
  
  % Let's get the function list
  if(nargin < 3)
    if(isempty(pipelineTree.Root.Children))
      logMsg('No functions found in the pipeline', 'e');
      return;
    end
    project = getappdata(netcalMainWindow, 'project');
    if(~isempty(project))
      folder = project.folder;
    else
      folder = appFolder;
    end
    [fileName, pathName] = uiputfile('*.json','Load pipeline', folder);
    if(~fileName)
      return;
    end
    pipelineFile = [pathName, fileName];
    verbose = true;
  else
    verbose = false;
  end
  % First update the nodes
  updateActiveNodeParams(pipelineTree);
  
  if(isempty(pipelineTree.Root.Children))
    return;
  end
  if(verbose)
    logMsgHeader('Saving pipeline', 'start');
  end
  completeList = [];
  

  if(length(pipelineTree.CheckedNodes) == 1 && strcmp(pipelineTree.CheckedNodes(1).Name, 'Root'))
    fullPipeline = true;
  else
    fullPipeline = false;
  end
  functionList = pipelineTree.Root.Children;

  fullList(1:length(functionList)) = struct;
  % Create the structure with the current pipeline functions
  for i = 1:length(functionList)
    if(fullPipeline || any(pipelineTree.CheckedNodes == functionList(i)))
      functionChecked = true;
    else
      functionChecked = false;
    end
    fullList(i).ID = functionList(i).UserData{1};
    fullList(i).name = functionList(i).TooltipString;
    fullList(i).options = functionList(i).UserData{2};
    
    fullList(i).options = fixNestedFields(fullList(i).options);
    
    fullList(i).optionsClass = class(functionList(i).UserData{2});
    fullList(i).handle = functionList(i).UserData{3};
    fullList(i).required = functionList(i).UserData{4};
    fullList(i).produced = functionList(i).UserData{5};
    fullList(i).checked = functionChecked;
    if(length(functionList(i).UserData) > 5)
      fullList(i).mode = functionList(i).UserData{6};
    else
      fullList(i).mode = [];
    end
    %%%
%       fn = fieldnames(fullList(i));
%       for t = 1:length(fn)
%         fullList(i).(fn{t})
%       end
    %%%
    if(isempty(fullList(i).produced))
      fullList(i).produced = {};
    end
    if(isempty(fullList(i).required))
      fullList(i).required = {};
    end
    fullnames = fieldnames(fullList(i));
    for j = 1:length(fullnames)
      if(strcmp(fullnames{j}, 'options'))
        fullList(i).(fullnames{j}) = fullList(i).(fullnames{j}).get();
        fnames = fieldnames(fullList(i).(fullnames{j}));
        for k = 1:length(fnames)
          % STRING is only defined after MATLAB 9.1
          if(iscellstr(fullList(i).(fullnames{j}).(fnames{k})) || ischar(fullList(i).(fullnames{j}).(fnames{k})))
            fullList(i).(fullnames{j}).(fnames{k}) = strrep(fullList(i).(fullnames{j}).(fnames{k}), '"', '');
          elseif(~verLessThan('matlab','9.1') && isstring(fullList(i).(fullnames{j}).(fnames{k})))
            fullList(i).(fullnames{j}).(fnames{k}) = char(fullList(i).(fullnames{j}).(fnames{k}));
          end
        end
      elseif(iscellstr(fullList(i).(fullnames{j})) || ischar(fullList(i).(fullnames{j})))
        fullList(i).(fullnames{j}) = strrep(fullList(i).(fullnames{j}), '"', '');
      end
    end
  end
  if(isempty(fullList))
    fullList = struct;
  end


  completeList = fullList;
  for it = 1:length(completeList)
    % First pass to see if some element is bad
    try
      if(it == 24)
        %completeList(it).options.backgroundImageCorrection.file = 'bla'
      end
      
       savejson([], completeList(it), 'ParseLogical', true);
    catch ME
      logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
      logMsg(sprintf('There was a problem saving pipeline function %d. %s. Try setting it back to its default values', it, completeList(it).name), netcalMainWindow, 'e');
      return;
    end
  end
  
  try
    pipelineData = savejson([], completeList, 'ParseLogical', true);
  catch ME
    logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), netcalMainWindow, 'e');
    logMsg('Could not save the current pipeline', netcalMainWindow, 'e');
    return;
  end
  
  % Now save it
  fID = fopen(pipelineFile, 'w');
  fprintf(fID, '%s', pipelineData);
  fclose(fID);
  if(verbose)
    logMsgHeader('Done!', 'finish');
  end
end

%[functionName, parametersClass, functionHandle, requiredFields, producedFields]
%UD: ID, options, optionsClass, required, produced
%tooltip: name

%--------------------------------------------------------------------------
function loadPipeline(~, ~, pipelineFile)
  if(nargin < 3)
    project = getappdata(netcalMainWindow, 'project');
    if(~isempty(project))
      folder = project.folder;
    else
      folder = appFolder;
    end
    [fileName, pathName] = uigetfile('*.json','Load pipeline', folder);
    if(~fileName)
      return;
    end
    pipelineFile = [pathName, fileName];
    verbose = true;
  else
    verbose = false;
  end
  if(verbose)
    logMsgHeader('Loading pipeline', 'start');
  end
  pfile = dir(pipelineFile);
  if(exist(pipelineFile, 'file') && pfile.bytes > 0)
    try
      fullPipelineData = loadjson(pipelineFile);
    catch ME
      logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
      errMsg = {'jsonlab toolbox missing. Please install it from the installDependencies folder'};
      uiwait(msgbox(errMsg,'Error','warn'));
      return;
    end
  else
    return;
  end

  if(~isempty(pipelineTree))
    delete(pipelineTree)
  end
  if(guiImprovements)
    if(~isempty(pipelineTreeListener))
      delete(pipelineTreeListener)
    end
  end
  % Recreate the trees
  pipelineTree = CheckboxTreePipeline('Parent',hs.pipelinePanel);
  if(guiImprovements)
    pipelineTreeListener = addlistener(pipelineTree.getJavaObjects.jTree, 'Keypressed', @clickPipeline);
  end
  %pipelineTree.FontName = 'Courier New';
  % Create tree nodes
  pipelineTree.RootVisible = false;
  pipelineTree.DndEnabled = true;
  pipelineTree.SelectionType = 'discontiguous';
  pipelineTree.SelectionChangeFcn = @selectedMethodPipeline;
  pipelineTree.CheckboxClickedCallback = @checkedMethodPipeline;
  if(guiImprovements)
    pipelineTree.ButtonDownFcn = @checkedHack;
  end
  pipelineTree.UserData = {};
%  pipelineTree.FontSize = textFontSize;
  
  pipelineTree.jCellRenderer.setFont(baseTreeFont);
    
  % Ugh
  if(length(fullPipelineData) == 1 && iscell(fullPipelineData))
    pipelineData = cell(1);
    pipelineData{1} = fullPipelineData{1};
  elseif(~iscell(fullPipelineData))
    pipelineData = cell(1);
    pipelineData{1} = fullPipelineData;
  else
    pipelineData = fullPipelineData;
  end

  if(isfield(pipelineData{1}, 'experiment'))
    pipelineData = pipelineData{1}.experiment;
    logMsg('Found old pipeline file. Loading just the experiment part', 'w');
  end
  if(iscell(pipelineData) && length(pipelineData) == 1)
      pipelineData = pipelineData{1};
  end
  for i = 1:length(pipelineData)
    try
      curEntry = pipelineData(i);
      if(isfield(curEntry, 'optionsClass'))
        opt = eval(curEntry.optionsClass);
        opt = opt.set(curEntry.options);
        opt = fixNestedFields(opt);
      else
        opt = [];
      end
      if(~iscell(curEntry.required))
        curEntry.required = num2cell(curEntry.required);
        curEntry.required = cellfun(@char,curEntry.required,'UniformOutput',false);
      end
      if(~iscell(curEntry.produced))
        curEntry.produced = num2cell(curEntry.produced);
        curEntry.produced = cellfun(@char,curEntry.produced,'UniformOutput',false);
      end
      if(~isfield(curEntry, 'mode'))
        curEntry.mode = [];
      end
      rr = uiextras.jTree.CheckboxTreeNode('Name', sprintf('%3.d. %s', i, curEntry.name), ...
                              'Parent', pipelineTree.Root, ...
                              'TooltipString', curEntry.name, ...
                              'Checked', curEntry.checked, ...
                              'UserData', {curEntry.ID, opt, curEntry.handle, curEntry.required, curEntry.produced, curEntry.mode});
      if(~isempty(curEntry.mode))
        switch curEntry.mode
          case 'projexp'
            colName = 'purple';
          case 'experiment'
            colName = 'blue';
          case 'project'
            colName = 'orange';
          case 'projexpDebug'
            colName = 'red';
          case 'experimentDebug'
            colName = 'red';
          case 'projectDebug'
            colName = 'red';
          otherwise
            colName = 'black';
        end
      else
        colName = 'black';
      end
      rr.Name = strrep(rr.Name, ' ', '&nbsp;');
      set(rr, 'Name', sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(get(rr, 'Name'), '<[^>]*>', '')));
      rr.Parent.Children; % WEIRD HACK FOR COMPTABILITY REASON IN MATLAB < 2017 - This is the Schroedinger pipeline, if I don't query the children they don't get saved
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), netcalMainWindow, 'w');
      logMsg(sprintf('Something went loading entry %d (%s) from the pipeline file', i, curEntry.name), 'w');
    end
  end
  pipelineTree.NodeDroppedCallback = @(s,e)pipelineTreeDnDCallback(s,e);
  setappdata(netcalMainWindow, 'pipelineTree', pipelineTree);
  if(verbose)
    logMsgHeader('Done!', 'finish');
  end
  
end
% Transpose fields back
%--------------------------------------------------------------------------
function curStruct = fixNestedFields(curStruct)
  fields = fieldnames(curStruct);
  for idx = 1:length(fields)
   curField = curStruct.(fields{idx});
%    if(strcmp(fields{idx}, 'labelGroups'))
%      curField
%    end
   if isstruct(curField)
     curField = fixNestedFields(curField);
   elseif(iscell(curField) && size(curField, 2) ~= 1 && size(curField, 1) == 1)
     if(~verLessThan('matlab', '9.2'))
       if(iscell(curField{1}))
         curField = [curField{:}]';
       else
        curField = curField';
       end
     else
       if(iscell(curField{1}))
         curField = [curField{:}]';
       end
     end
   elseif(~verLessThan('matlab', '9.2') && isstring(curField)) % FIX string bugs
     tmpField = cell(size(curField));
     for itt = 1:length(tmpField)
      tmpField{itt} = curField{itt};
     end
     curField = tmpField;
   end
   curStruct.(fields{idx}) = curField;
   if(strcmpi(class(curStruct.(fields{idx})), 'java.io.File'))
     curStruct.(fields{idx}) = char(curField);
   end
  end
end

%--------------------------------------------------------------------------
function modules = loadModules(DEVELOPMENT)
  if(nargin < 1)
    DEVELOPMENT = false;
  end
  % Name, Tag (unique), Predecesor Tag, Function callback, Field it depends on, Field on completion, separator  (optional true,false), experiment selection mode (single/multiple), default both
  modules = {...
  ...
  {'Analysis', 'analysis', [], [], [], [], [], {'single', 'multiple'}}, ...
    {'Fluorescence', 'fluorescence', 'analysis', [], 'handle', []}, ...
      {'Drift correction', 'driftCorr', 'fluorescence', {@menuExperimentGlobalAnalysis, @recordingDriftCorrection, recordingDriftCorrectionOptions}, 'handle', 'affineTransform'}, ...
      {'Preprocessing', 'preprocessing', 'fluorescence', [], 'handle', 'avgImg'}, ...
        {'Standard', 'preprocessingStandard', 'preprocessing', {@menuExperimentGlobalAnalysis, @preprocessExperiment, preprocessExperimentOptions}, 'handle', 'avgImg'}, ...
        {'Percentile', 'preprocessingPercentile', 'preprocessing', {@menuExperimentGlobalAnalysis, @preprocessExperimentPercentile, preprocessExperimentPercentileOptions}, 'avgImg', 'percentileImg'}, ...
        {'Denoising', 'preprocessingDenoising', 'preprocessing', {@menuExperimentGlobalAnalysis, @denoiseRecording, denoiseRecordingOptions}, 'handle', 'denoisedData'}, ...
        {'Power spectrum', 'preprocessingPSD', 'preprocessing', {@menuExperimentGlobalAnalysis, @computePSDavg, computePSDavgOptions}, 'handle', 'avgPSD'}, ...
      {'ROI detection', 'roiSelection', 'fluorescence', [], [], []}, ...
        {'Supervised ROI detection', 'manualROIdetection', 'roiSelection', {@menuNewGuiWindow, @viewROI}, 'avgImg', 'ROI', false, 'single'}, ...
        {'Automatic ROI detection', 'automaticROIdetection', 'roiSelection', {@menuExperimentGlobalAnalysis, @automaticROIdetection, ROIautomaticOptions}, 'avgImg', 'ROI'}, ...
        {'CellSort', 'cellSortBase', 'roiSelection', [], 'denoisedData', 'ROI'}, ...
          {'Automatic ROI detection', 'cellSortROIdetection', 'cellSortBase', {@menuExperimentGlobalAnalysis, @automaticROIdetectionCellSort, ROIautomaticCellSortOptions}, 'denoisedData', 'ROI'}, ...
          {'ROI refinement', 'cellSortROIcleaning', 'cellSortBase', {@menuExperimentGlobalAnalysis, @cleanROIfromCellSort, cleanROIfromCellSortOptions}, 'ROI', 'ROI'}, ...
        {'Import ROI', 'importROImenu', 'roiSelection', {@menuExperimentGlobalAnalysis, @importROI, importROIoptions, 'project'}, 'handle', 'ROI'}, ...
      {'Traces extraction', 'extractTraces', 'fluorescence', {@menuExperimentGlobalAnalysis, @extractTraces, extractTracesOptions}, 'ROI', 'rawTraces'}, ...
      {'Traces correction', 'correctTraces', 'fluorescence', {@menuExperimentGlobalAnalysis, @correctTraces, correctTracesOptions}, 'rawTraces', 'traces'}, ...
      {'Similarity', 'similarity', 'fluorescence', {@menuExperimentGlobalAnalysis, @fluorescenceAnalysisSimilarity, similarityOptions}, 'traces', 'similarityOrder'}, ...
      {'q-Complexity-entropy', 'qcec', 'fluorescence', {@menuExperimentGlobalAnalysis, @measureTracesQCEC, measureTracesQCECoptions}, 'traces', 'qCEC'}, ...
      {'Bursts', 'bursts', 'fluorescence', [], 'rawTraces', []}, ...
        {'Supervised detection', 'manualBursts', 'bursts', {@menuNewGuiWindow, @viewBursts}, 'rawTraces', 'traceBursts', false, 'single'}, ...
        {'Automatic detection', 'automaticBursts', 'bursts', {@menuExperimentGlobalAnalysis, @burstDetection, burstDetectionOptions}, 'rawTraces', 'traceBursts'}, ...
      {'Export Recording', 'recording', 'fluorescence', {@menuExperimentGlobalAnalysis, @exportRecording, exportMovieOptions}, 'handle', []}, ...
      {'Cut traces', 'cut', 'fluorescence', {@menuExperimentGlobalAnalysis, @menufluorescenceAnalysisCutTraces, []}, 'rawTraces', [], true}, ...
      {'Rebase time', 'rebase', 'fluorescence', {@menuExperimentGlobalAnalysis, @menufluorescenceAnalysisRebaseTime, []}, 'rawTraces', []}, ...
      {'Change Active Image', 'activeImg', 'fluorescence', {@menuExperimentGlobalAnalysis, @setActiveImage, setActiveImageOptions}, 'width', []}, ...
    {'Spike inference', 'spikeInference', 'analysis', [], 'rawTraces', []}, ...
      {'Training', 'spikeInferenceTraining', 'spikeInference', {@menuNewGuiWindow, @viewInferenceTraining}, 'rawTraces', 'spikes', false, 'single'}, ...
      {'Run', 'spikeInferenceRun', 'spikeInference', [], 'rawTraces', []}, ...
        {'Peeling', 'spikeInferencePeeling', 'spikeInferenceRun', {@menuExperimentGlobalAnalysis, @spikeInferencePeeling, peelingOptions}, 'rawTraces', 'spikes'}, ...
        {'Foopsi', 'spikeInferenceFoopsi', 'spikeInferenceRun', {@menuExperimentGlobalAnalysis, @spikeInferenceFoopsi, foopsiOptions}, 'rawTraces', 'spikes'}, ...
        {'Schmitt', 'spikeInferenceSchmitt', 'spikeInferenceRun', {@menuExperimentGlobalAnalysis, @spikeInferenceSchmitt, schmittOptions}, 'rawTraces', 'spikes'}, ...
        {'Oasis', 'spikeInferenceOasis', 'spikeInferenceRun', {@menuExperimentGlobalAnalysis, @spikeInferenceOasis, oasisOptions}, 'rawTraces', 'spikes'}, ...
        {'MLspike', 'spikeInferenceMLspike', 'spikeInferenceRun', {@menuExperimentGlobalAnalysis, @spikeInferenceMLspike, MLspikeOptions}, 'rawTraces', 'spikes'}, ...
      {'Bursts', 'spikeBursts', 'spikeInference', [], 'spikes', []}, ...
        {'Standard', 'spikeBurstsStandard', 'spikeBursts', {@menuExperimentGlobalAnalysis, @burstDetectionSpikes, burstDetectionSpikesOptions}, 'spikes', 'spikeBursts'}, ...
        {'ISI_N', 'spikeBurstsISIN', 'spikeBursts', {@menuExperimentGlobalAnalysis, @burstDetectionISIN, burstDetectionISINoptions}, 'spikes', 'spikeBursts'}, ...
        {'ISI_N explorer', 'spikeBurstsISINexplorer', 'spikeBursts', {@menuExperimentGlobalAnalysis, @burstDetectionISINexplorer, burstDetectionISINexplorerOptions}, 'spikes', 'spikeBursts'}, ...
        {'ISI_N automatic', 'spikeBurstsISINautomatic', 'spikeBursts', {@menuExperimentGlobalAnalysis, @burstDetectionISINautomatic, burstDetectionISINautomaticOptions}, 'spikes', 'spikeBursts'}, ...
        {'Surprise', 'spikeBurstsSurprise', 'spikeBursts', {@menuExperimentGlobalAnalysis, @burstDetectionSurprise, burstDetectionSurpriseOptions}, 'spikes', 'spikeBursts'}, ...
        {'X (recommended)', 'spikeBurstsX', 'spikeBursts', {@menuExperimentGlobalAnalysis, @burstDetectionX, burstDetectionXoptions}, 'spikes', 'spikeBursts'}, ...
      {'Features', 'spikeInferenceFeatures', 'spikeInference', {@menuExperimentGlobalAnalysis, @getSpikesFeatures, spikeFeaturesOptions}, 'spikes', 'spikeFeatures'}, ...
      {'q-Complexity-entropy', 'qcecSpikes', 'spikeInference', {@menuExperimentGlobalAnalysis, @measureTracesQCEC, measureTracesQCECoptions}, 'spikes', 'qCEC'}};
    if(DEVELOPMENT)
      modules = {modules{:}, ...
      {'Glia analysis', 'gliaAnalysis', 'analysis', [], 'handle', []}, ...
        {'Average movie', 'gliaAverageMovie', 'gliaAnalysis', {@menuExperimentGlobalAnalysis, @gliaAverageMovie, gliaAverageMovieOptions} , 'handle', 'gliaAverageFrame'}, ...
        {'Optic flow', 'gliaOpticFlow', 'gliaAnalysis', {@menuExperimentGlobalAnalysis, @gliaOpticFlow, gliaOpticFlowOptions}, 'gliaAverageFrame', 'gliaOpticFlowAverage'}, ...
        {'Identify events', 'gliaIdentifyEvents', 'gliaAnalysis', {@menuExperimentGlobalAnalysis, @identifyGlialEvents, glialEventDetectionOptions}, 'gliaOpticFlowAverage', 'glialEvents'}, ...
        {'Calculate Events Statistics', 'gliaCalculateEventsStatistics', 'gliaAnalysis', {@menuExperimentGlobalAnalysis, @calculateGlialEventsStatistics, []}, 'glialEvents', 'glialEventsStatistics'}};
    else
      modules = {modules{:}, ...
      {'Glia analysis', 'gliaAnalysis', 'analysis', [], 'handle', []}, ...
        {'Average movie', 'gliaAverageMovie', 'gliaAnalysis', [] , 'handle', 'gliaAverageFrame'}, ...
        {'Optic flow', 'gliaOpticFlow', 'gliaAnalysis', [], 'gliaAverageFrame', 'gliaOpticFlowAverage'}, ...
        {'Identify events', 'gliaIdentifyEvents', 'gliaAnalysis', [], 'gliaOpticFlowAverage', 'glialEvents'}};
    end
    modules = {modules{:}, ...
    {'Avalanche analysis', 'avalancheAnalysis', 'analysis', [], 'spikes', []}, ...
      {'Distributions', 'avalancheDistributions', 'avalancheAnalysis', {@menuExperimentGlobalAnalysis, @avalancheAnalysisDistributions, avalancheOptions, 'population'}, 'spikes', []}, ...
      {'Branching ratio', 'avalancheBranchingRatio', 'avalancheAnalysis', {@menuExperimentGlobalAnalysis, @avalancheAnalysisBranchingRatio, avalancheOptions, 'population'}, 'spikes', []}, ...
      {'Exponents', 'avalancheExponents', 'avalancheAnalysis', {@menuExperimentGlobalAnalysis, @avalancheAnalysisExponents, avalancheOptions}, 'avalanches', []}, ...
    {'Network inference', 'networkInference', 'analysis', [], 'traces', []}, ...
      {'Partial correlation (incompatible)', 'networkInferenceXcorr', 'networkInference', {@menuExperimentGlobalAnalysis, @networkInferenceXcorr, networkInferenceXcorrOptions}, 'spikes', []}, ...
      {'Generalized Transfer Entropy', 'networkInferenceGTE', 'networkInference', {@menuExperimentGlobalAnalysis, @networkInferenceGTEfast, networkInferenceGTEfastOptions}, 'spikes', 'GTE', []}, ...
      {'Set active network', 'networkInferenceActive', 'networkInference', {@menuExperimentGlobalAnalysis, @setActiveNetwork, setActiveNetworkOptions}, [], 'RS', true}, ...
      {'Export active network to GEPHI', 'networkInferenceExport', 'networkInference', {@menuExperimentGlobalAnalysis, @exportActiveNetworkToGephi, exportActiveNetworkToGephiOptions}, 'RS', []}};
%     if(DEVELOPMENT)
%       modules = {modules{:}, ...
%       {'Time Delayed Mutual Information', 'networkInferenceTDMI', 'networkInference', {@menuExperimentGlobalAnalysis, @networkInferenceTMDI, networkInferenceTMDIOptions}, 'spikes', []}, ...
%       {'Generalized Transfer Entropy', 'networkInferenceGTE', 'networkInference', {@menuExperimentGlobalAnalysis, @networkInferenceGTE, networkInferenceGTEOptions}, 'spikes', []}, ...
%       {'Granger Causality', 'networkInferenceGC', 'networkInference', {@menuExperimentGlobalAnalysis, @networkInferenceGC, networkInferenceGCOptions}, 'spikes', []}};
%     else
%       modules = {modules{:}, ...
%       {'Time Delayed Mutual Information', 'networkInferenceTDMI', 'networkInference', [], 'spikes', []}, ...
%       {'Granger Causality', 'networkInferenceGC', 'networkInference', [], 'spikes', []}};
%     end
  modules = {modules{:}, ...
  {'View', 'view', [], [], [], [], false, 'single'}, ...
    {'Recording', 'viewRecording', 'view', {@menuNewGuiWindow, @viewRecording}, 'handle', []}, ...
    {'ROI', 'viewROI', 'view', {@menuNewGuiWindow, @viewROI}, 'avgImg', 'ROI'}, ...
    {'Traces', 'viewTraces', 'view', {@menuNewGuiWindow, @viewTraces}, 'rawTraces', []}, ...
    {'Bursts', 'viewBursts', 'view', {@menuNewGuiWindow, @viewBursts}, 'rawTraces', 'traceBursts'}, ...
    {'Spikes (raster)', 'viewSpikes', 'view', {@menuNewGuiWindow, @viewSpikes}, 'spikes', []}, ...
    {'Groups', 'viewGroups', 'view', {@menuNewGuiWindow, @viewGroups}, 'ROI', []}, ...
    {'Glia', 'viewGlia', 'view', {@menuNewGuiWindow, @viewGlia}, 'gliaAverageFrame', []}, ...
    {'Denoiser', 'viewDenoiser', 'view', {@menuNewGuiWindow, @viewDenoiser}, 'avgImg', 'denoisedData'}, ...
    {'Trace fixer', 'viewTraceFixer', 'view', {@menuNewGuiWindow, @traceFixer}, 'rawTraces', []}, ...
  ...
  {'View', 'viewMultiple', [], [], [], [], false, 'multiple'}, ...
    {'Traces', 'viewMultipleTraces', 'viewMultiple', {@menuNewProjectGuiWindow, @viewTracesMultiExperiment}, 'rawTraces', []}, ...
  ...
  {'Statistics', 'statistics', [], [], [], [], false, 'multiple'}, ...
    {'Groups', 'groupStatistics', 'statistics', {@menuExperimentGlobalAnalysis, @plotGroupStatistics, plotGroupStatisticsOptions}, 'ROI', []}, ...
    {'Fluorescence', 'fluorescenceStatistics', 'statistics', [], 'rawTraces', []}, ...
      {'Bursts', 'fluorescenceBurstStatistics', 'fluorescenceStatistics', {@menuExperimentGlobalAnalysis, @plotFluorescenceBurstStatistics, plotFluorescenceBurstStatisticsOptions}, 'traceBursts', []}, ...
      {'KCl Statistics', 'KClStatistics', 'fluorescenceStatistics', {@menuExperimentGlobalAnalysis, @plotAcuteKClStatistics, plotAcuteKClStatisticsOptions}, 'KClProtocolData', []}, ...
    {'Spikes', 'spikeStatisticsBase', 'statistics', [], 'spikes', []}, ...
      {'Spike features', 'spikeStatistics', 'spikeStatisticsBase', {@menuExperimentGlobalAnalysis, @plotSpikeStatistics, plotSpikeStatisticsOptions}, 'spikeFeatures', []}, ...
      {'Spike features (schmitt)', 'spikeStatisticsSchmitt', 'spikeStatisticsBase', {@menuExperimentGlobalAnalysis, @plotSchmittSpikeStatistics, plotSchmittSpikeStatisticsOptions}, 'schmittSpikesData', []}, ...
      {'Bursts', 'spikeBurstStatistics', 'spikeStatisticsBase', {@menuExperimentGlobalAnalysis, @plotSpikeStatistics, plotSpikeStatisticsOptions}, 'spikeBursts', []}, ...
    {'Network', 'networkStatisticsBase', 'statistics', [], 'RS', []}, ...
      {'Network statistics', 'networkStatistics', 'networkStatisticsBase', {@menuExperimentGlobalAnalysis, @plotNetworkStatistics, plotNetworkStatisticsOptions}, 'RS', []}, ...
    {'Treatments', 'statisticsTreatments', 'statistics', [], [], [], true, 'multiple'}, ...
      {'Groups', 'groupStatisticsTreatment', 'statisticsTreatments', {@menuExperimentGlobalAnalysis, @plotGroupStatisticsTreatment, plotGroupStatisticsTreatmentOptions}, 'ROI', []}, ...
      {'Fluorescence bursts', 'burstStatisticsTreatment', 'statisticsTreatments', {@menuExperimentGlobalAnalysis, @plotFluorescenceBurstStatisticsTreatment, plotFluorescenceBurstStatisticsTreatmentOptions}, 'traceBursts', []}, ...
      {'Spike features', 'spikeStatisticsTreatment', 'statisticsTreatments', {@menuExperimentGlobalAnalysis, @plotSpikeStatisticsTreatment, plotSpikeStatisticsTreatmentOptions}, 'spikeFeatures', []}, ...
      {'Spike bursts', 'spikeBurstStatisticsTreatment', 'statisticsTreatments', {@menuExperimentGlobalAnalysis, @plotSpikeBurstStatisticsTreatment, plotSpikeBurstStatisticsTreatmentOptions}, 'spikeBursts', []}, ...
      {'Network statistics', 'networkStatisticsTreatment', 'statisticsTreatments', {@menuExperimentGlobalAnalysis, @plotNetworkStatisticsTreatment, plotNetworkStatisticsTreatmentOptions}, 'RS', []}, ...
    {'Principal Component Analysis', 'PCA', 'statistics', [], [], [], true}, ...
      {'Spikes features', 'spikesPCA', 'PCA', @menuAggregatedPCA, [], []}, ...
      {'KCl', 'stimulationPCA', 'PCA', @menuAggregatedStimulationPCA, [], []}, ...
    {'Populations changes between treatments', 'compareExperiments', 'statistics', @menuAggregatedCompareExperiments, [], []}, ...
  ...
  {'Pipeline', 'pipeline', [], [], [], [], false, 'pipeline'}, ...
    {'Check experiment pipeline', 'checkPipeline', 'pipeline', @pipelineCheck, [], []}, ...
    {'Run', 'runPipeline', 'pipeline', [], [], []}, ...
    {'Sequential', 'runPipelineSingle', 'runPipeline', {@pipelineRun, false}, [], []}, ...
    {'Parallel', 'runPipelineParallel', 'runPipeline', {@pipelineRun, true}, [], []}, ...
    {'Load', 'loadPipeline', 'pipeline', @loadPipeline, [], [], true}, ...
    {'Save', 'savePipeline', 'pipeline', @savePipeline, [], []}, ...
  };
end
     
end