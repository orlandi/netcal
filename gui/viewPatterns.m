function [hFigW, experiment] = viewPatterns(experiment, varargin)
% VIEWPATTERNS shows the patterns of a given experiment
%
% USAGE:
%    [hFigW, experiment] = viewPatterns(experiment)
%
% INPUT arguments:
%    experiment - experiment structure from loadExperiment
%
% OUTPUT arguments:
%    hFigW - figure handle
%
%    experiment - experiment structure from loadExperiment
%
% EXAMPLE:
%    [hFigW, experiment] = viewPatterns(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also loadExperiment

%#ok<*AGROW>
%#ok<*ASGLU>
%#ok<*FXUP>

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Initialization
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
oldExperiment = experiment;
gui = gcbf;
% Hack

if(~isempty(gui))
   gui = getappdata(gui, 'gui');
end

hFigW = [];

if(nargin < 2)
  mode = 'traces';
else
  mode = varargin{1};
end
if(isempty(mode))
  mode = 'traces';
end

if(~isempty(gui))
  project = getappdata(gui, 'project');
else
  project = [];
end

textFontSize = 10;
headerFontSize = 12;
minGridBorder = 1;

[patterns, basePatternList] = generatePatternList(experiment, mode);

import uiextras.jTree.*;

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hs.mainWindow = figure('Visible','off',...
                       'Resize','on',...
                       'Toolbar', 'figure',...
                       'Tag','viewGroups', ...
                       'NumberTitle', 'off',...
                       'MenuBar', 'none',...
                       'DockControls','off',...
                       'Name', ['Pattern viewer: ' experiment.name],...
                       'CloseRequestFcn', @closeCallback);
hFigW = hs.mainWindow;
hFigW.Position = setFigurePosition(gui, 'width', 1000, 'height', 600);
if(~isempty(gui))
  setappdata(hFigW, 'logHandle', getappdata(gcbf, 'logHandle'));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create components
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% The menu
hs.menu.file.root = uimenu(hs.mainWindow, 'Label', 'File');
uimenu(hs.menu.file.root, 'Label', 'Exit and discard changes', 'Callback', {@closeCallback, false});
uimenu(hs.menu.file.root, 'Label', 'Exit and save changes', 'Callback', {@closeCallback, true});
uimenu(hs.menu.file.root, 'Label', 'Exit (default)', 'Callback', @closeCallback);


hs.menu.analysis.root = uimenu(hs.mainWindow, 'Label', 'Analysis');
hs.menu.analysis.simplification = uimenu(hs.menu.analysis.root, 'Label', 'Pattern Simplification', 'Callback', @eventSimplification);
hs.menu.analysis.sorting = uimenu(hs.menu.analysis.root, 'Label', 'Automatic pattern classification', 'Callback', @eventAutomaticClassification);
hs.menu.analysis.resample = uimenu(hs.menu.analysis.root, 'Label', 'Pattern resample', 'Callback', @patternResample);
%hs.menu.stats.root = uimenu(hs.mainWindow, 'Label', 'Statistics');

hs.menu.io.root = uimenu(hs.mainWindow, 'Label', 'Import/Export');
hs.menu.io.export = uimenu(hs.menu.io.root, 'Label', 'Export', 'Callback', @exportPatterns);
hs.menu.io.import = uimenu(hs.menu.io.root, 'Label', 'Import from file', 'Callback', {@importPatterns, 'file'});
hs.menu.io.importProject = uimenu(hs.menu.io.root, 'Label', 'Import from another experiment', 'Callback', {@importPatterns, 'project'});

% hs.menu.export.root = uimenu(hs.mainWindow, 'Label', 'Export');
% hs.menu.export.current = uimenu(hs.menu.export.root, 'Label', 'Current image', 'Callback', @exportCurrentImage);

% Main grid
hs.mainWindowSuperBox = uix.VBox('Parent', hs.mainWindow);
hs.mainWindowGrid = uix.Grid('Parent', hs.mainWindowSuperBox);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Empty left
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Groups column
uix.Empty('Parent', hs.mainWindowGrid);
hs.patternListVbox = uix.VBox('Parent', hs.mainWindowGrid);
hs.groupPanel = uix.Panel('Parent', hs.patternListVbox, ...
                               'BorderType', 'none', 'FontSize', textFontSize, ...
                               'Title', 'Pattern list');
hs.infoPanelParent = uix.Panel('Parent', hs.patternListVbox, ...
                               'BorderType', 'none', 'FontSize', headerFontSize,...
                               'Title', 'Pattern properties');
hs.infoPanel = uicontrol('Parent', hs.infoPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background', 'w');

set(hs.patternListVbox, 'Heights', [-3 -1], 'Padding', 5, 'Spacing', 5);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uix.Empty('Parent', hs.mainWindowGrid);

% The axes
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowFramesAxes = axes('Parent', uicontainer('Parent', hs.mainWindowFramesPanel));
axis tight;
set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
box on;
hold on;
xlabel('time (s)');
ylabel('Normalized fluroescence');
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% COLUMN START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Empty right
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);
uix.Empty('Parent', hs.mainWindowGrid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Finish superbox
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Now the log panel
hs.logPanelParent = uix.Panel('Parent', hs.mainWindowSuperBox, ...
                               'BorderType', 'none');
hs.logPanel = uicontrol('Parent', hs.logPanelParent, ...
                      'style', 'edit', 'max', 5, 'Background','w');
set(hs.mainWindowSuperBox, 'Heights', [-1 100], 'Padding', 0, 'Spacing', 0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Fianl init
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

patternTree = [];
% Prepare the multiple experiment panel
patternTreeContextMenu = [];
patternTreeContextMenuRoot = [];

set(hs.mainWindowGrid, 'Widths', [minGridBorder -1 -3 minGridBorder], ...
    'Heights', [minGridBorder -1 minGridBorder]);

cleanMenu();

hs.mainWindow.Visible = 'on';

% Finish the new log panel
jScrollPanel = findjobj(hs.logPanel);
try
    jScrollPanel.setVerticalScrollBarPolicy(jScrollPanel.java.VERTICAL_SCROLLBAR_AS_NEEDED);
    jScrollPanel = jScrollPanel.getViewport;
catch
    % may possibly already be the viewport, depending on release/platform etc.
end
hs.logPanelEditBox = handle(jScrollPanel.getView,'CallbackProperties');
hs.logPanelEditBox.setEditable(false);
logMessage(hs.logPanelEditBox, '<b>Message log</b>');

if(~isempty(gui))
  parentHandle = getappdata(hFigW, 'logHandle');
  setappdata(hFigW, 'logHandle', [parentHandle hs.logPanelEditBox]);
else
  setappdata(hs.mainWindow, 'logHandle', hs.logPanelEditBox);
end
% Righ click menu
hs.rightClickMenu.root = uicontextmenu;
hs.mainWindowFramesAxes.UIContextMenu = hs.rightClickMenu.root;
hs.rightClickMenu.showTraceRaw = uimenu(hs.rightClickMenu.root, 'Label','Show neuron raw trace', 'Callback', {@rightClickPlotNeuronTrace, 'raw'});
hs.rightClickMenu.showTraceSmoothed = uimenu(hs.rightClickMenu.root, 'Label','Show neuron smoothed trace', 'Callback', {@rightClickPlotNeuronTrace, 'smoothed'});
if(~isfield(experiment, 'traces'))
  hs.rightClickMenu.showTraceRaw.Enable = 'off';
  hs.rightClickMenu.showTraceSmoothed.Enable = 'off';
end

updatePatternTree();

% Get the underlying Java editbox, which is contained within a scroll-panel
jScrollPanel = findjobj(hs.infoPanel);
try
  jScrollPanel.setVerticalScrollBarPolicy(jScrollPanel.java.VERTICAL_SCROLLBAR_AS_NEEDED);
  jScrollPanel = jScrollPanel.getViewport;
catch
  % may possibly already be the viewport, depending on release/platform etc.
end

hs.infoPanelEditBox = handle(jScrollPanel.getView,'CallbackProperties');
hs.infoPanelEditBox.setEditable(false);

printPatternInfo();

%if(isempty(gui))
  waitfor(hFigW);
%end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%--------------------------------------------------------------------------
function closeCallback(~, ~, varargin)
  if(isequaln(oldExperiment, experiment))
    experimentChanged = false;
  else
    experimentChanged = true;
  end
  guiSave(experiment, experimentChanged, varargin{:});
  try
    resizeHandle = getappdata(gui, 'ResizeHandle');
    if(isa(resizeHandle,'function_handle'))
      resizeHandle([], []);
    end
  catch
  end
  % Finally close the figure
  delete(hFigW);
end 

%--------------------------------------------------------------------------
function eventAutomaticClassification(~, ~)
  threshold = 0.95;
  maxRiseTime = 10;
  [patterns, basePatternList] = generatePatternList(experiment, mode);
  for it = 1:length(patterns)
    % Skip bursts
    switch patterns{it}.type
      case {'bursts', 'importedBursts'}
        continue;
    end
    maxF = max(patterns{it}.F);
    %minF = min(patterns{it}.F);
    tThreshold = patterns{it}.t(find(patterns{it}.F > maxF*threshold, 1, 'first'));
    if(tThreshold < maxRiseTime)
      newPattern = 'below';
    else
      newPattern = 'above';
    end
    patterns{it}.basePattern = newPattern;
    switch patterns{it}.type
      case 'auto'
        experiment.patternFeatures({patterns{it}.idx}).basePattern = newPattern;
      case 'user'
        experiment.learningEventListPerTrace{patterns{it}.idx(1)}{patterns{it}.idx(2)}.basePattern = newPattern;
      case 'bursts'
        experiment.burstPatterns.(patterns{it}.idx{1}){patterns{it}.idx{2}}{patterns{it}.idx{3}}.basePattern = newPattern;
    end
  end
  
  updatePatternTree();
end

%--------------------------------------------------------------------------
function exportPatterns(~, ~)
  [patterns, basePatternList] = generatePatternList(experiment, mode);

  defaultFile = [experiment.folder filesep 'patterns.json'];
  [fileName, pathName] = uiputfile('*.json','Save patterns file as', defaultFile);
  fileName = [pathName fileName];
 
  try
    fileData = savejson([], patterns, 'ParseLogical', true, 'SingletCell', 1, 'ArrayToStruct', 1);
  catch ME
    if(strcmpi(ME.identifier, 'MATLAB:UndefinedFunction'))
      errMsg = {'jsonlab toolbox missing. Please install it from the installDependencies folder'};
      uiwait(msgbox(errMsg,'Error','warn'));
    else
      logMsg('Something went wrong with json. Is jsonlab toolbox installed?', 'e');
    end
    return;
  end
  fID = fopen(fileName, 'w');
  fprintf(fID, '%s', fileData);
  fclose(fID);
  logMsg(sprintf('%d patterns successfully exported', length(patterns)));
end

%--------------------------------------------------------------------------
function importPatterns(~, ~, type)
  switch type
    case 'file'
      defaultFile = [experiment.folder filesep 'patterns.json'];
      [fileName, pathName] = uigetfile('*.json','Load group file as', defaultFile);
      if(isempty(fileName) || fileName(1) == 0)
        return;
      end
      fileName = [pathName fileName];
      try
        newPatterns = loadjson(fileName, 'SimplifyCell', 0);
      catch ME
         if(strcmpi(ME.identifier, 'MATLAB:UndefinedFunction'))
           errMsg = {'jsonlab toolbox missing. Please install it from the installDependencies folder'};
           uiwait(msgbox(errMsg,'Error','warn'));
         else
          logMsg('Something went wrong with json. Is jsonlab toolbox installed?', 'e');
         end
         return;
      end
    case 'project'
      try
        [selection, ok] = listdlg('PromptString', 'Select experiment to compare to', 'ListString', namesWithLabels([], gui), 'SelectionMode', 'single');
      catch
        logMsg('Could not load project experiment list', 'e');
        return;
      end

      if(~ok)
        return;
      end
      ncbar.automatic('Loading patterns');
      experimentFile = [project.folderFiles project.experiments{selection} '.exp'];
      newExperiment = loadExperiment(experimentFile, 'verbose', false, 'project', project);
      %[newPatterns, ~] = generatePatternList(newExperiment, 'traces');
      [newPatterns, ~] = generatePatternList(newExperiment, mode);
      ncbar.close();
  end
  % Append or ad to the import list
  if(~isfield(experiment, 'importedPatternFeatures'))
    experiment.importedPatternFeatures = {};
  end
  if(~isfield(experiment, 'importedBurstPatternFeatures'))
    experiment.importedBurstPatternFeatures = {};
  end
  for it = 1:length(newPatterns)
    switch newPatterns{it}.type
      case {'auto', 'user', 'imported'};
        % Only import trace-type events if in the traces mode
        if(~strcmpi(mode, 'traces'))
          continue;
        end
        patternField = 'importedPatternFeatures';
        patternType = 'imported';
      case {'bursts', 'importedBursts'}'
        % Only import burst-type events if in the bursts mode
        if(~strcmpi(mode, 'bursts'))
          continue;
        end
        patternField = 'importedBurstPatternFeatures';
        patternType = 'importedBursts';
    end
    experiment.(patternField){end+1} = struct;
    % Check for repeated names against the old set
    newName = newPatterns{it}.name;
    for it2 = 1:length(patterns)
      if(strcmpi(patterns{it2}.name, newPatterns{it}.name))
        logMsg(sprintf('Found repeated pattern name %s, adding an underscore', newPatterns{it}.name), 'w');
        newName = [newPatterns{it}.name '_'];
      end
    end
    experiment.(patternField){end}.name = newName;
    experiment.(patternField){end}.basePattern = newPatterns{it}.basePattern;
    experiment.(patternField){end}.type = patternType;
    experiment.(patternField){end}.signal = newPatterns{it}.F;
    experiment.(patternField){end}.threshold = newPatterns{it}.threshold;
  end
  
  logMsg(sprintf('%d Patterns successfully imported', length(newPatterns)));
  [patterns, basePatternList] = generatePatternList(experiment, mode);
  updatePatternTree();
end

%--------------------------------------------------------------------------
function patternResample(~, ~)
  answer = inputdlg({'Old frame rate', 'New frame rate'}, 'Pattern resample', [1 60], {num2str(experiment.fps), num2str(experiment.fps)});
  if(isempty(answer))
      return;
  end
  oldRate = str2double(answer{1});
  newRate = str2double(answer{2});
  
  [patterns, basePatternList] = generatePatternList(experiment, mode);
  for currPattern = 1:length(patterns)
    oldT = 0:1/oldRate:((length(patterns{currPattern}.t)-1)/oldRate);
    newT = 0:1/newRate:((length(patterns{currPattern}.t)-1)/oldRate);
    newF = interp1(oldT, patterns{currPattern}.F, newT);
    patterns{currPattern}.F = newF;
    patterns{currPattern}.t = newT;
    
    % This is a mess, needs to be changed
    if(strcmpi(patterns{currPattern}.type, 'auto'))
      experiment.patternFeatures{patterns{currPattern}.idx}.signal = newF;
    end
    if(strcmpi(patterns{currPattern}.type, 'imported'))
      experiment.importedPatternFeatures{patterns{currPattern}.idx}.signal = newF;
    end
    if(strcmpi(patterns{currPattern}.type, 'importedBursts'))
      experiment.importedBurstPatternFeatures{patterns{currPattern}.idx}.signal = newF;
    end
    if(strcmpi(patterns{currPattern}.type, 'user'))
      patternFullIdx = [patterns{currPattern}.idx(1), patterns{currPattern}.idx(2)];
      traceList = unique(patternFullIdx(:, 1));
      for it = 1:length(traceList)
        nlist = find(patternFullIdx(:, 1) == traceList(it));
        experiment.learningEventListPerTrace{traceList(it)}{patternFullIdx(nlist, 2)}.signal = newF;
      end
    end
  end
end

%--------------------------------------------------------------------------
function eventSimplification(~, ~)
  [success, eventSimplificationOptionsCurrent] = preloadOptions(experiment, eventSimplificationOptions, gui, true, false);
  if(~success)
    return;
  end
  experiment.eventSimplificationOptionsCurrent = eventSimplificationOptionsCurrent;
  threshold = experiment.eventSimplificationOptionsCurrent.threshold;
  
  done = false;
  patternsRemoved = 0;
  while(~done)
    [patterns, basePatternList] = generatePatternList(experiment, mode);
    done = true;
    for it1 = 1:length(patterns)
      px = patterns{it1};
      for it2 = (it1+1):length(patterns)
        py = patterns{it2};
        % Patterns must have the same base pattern
        if(~strcmpi(px.basePattern, py.basePattern))
          continue;
        end
        L = min(length(px.F), length(py.F));
        x = px.F(1:L);
        y = py.F(1:L);
        % For now, corrcoef, should use normalized xcorr instead
        R = corrcoef(x, y);
        if(R(1,2) > threshold)
          done = false;
          % Keep the shortest one - or the first
          if(length(px.F) <= length(py.F))
            toDelete = it2;
          else
            toDelete = it1;
          end
          if(strcmpi(patterns{toDelete}.type, 'auto'))
            autoToDelete = patterns{toDelete}.idx;
            experiment.patternFeatures(autoToDelete) = [];
          end
          if(strcmpi(patterns{toDelete}.type, 'imported'))
            importedToDelete = patterns{toDelete}.idx;
            experiment.importedPatternFeatures(importedToDelete) = [];
          end
          if(strcmpi(patterns{toDelete}.type, 'importedBursts'))
            importedBurstsToDelete = patterns{toDelete}.idx;
            experiment.importedBurstPatternFeatures(importedBurstsToDelete) = [];
          end
          if(strcmpi(patterns{toDelete}.type, 'user'))
            userToDelete = [patterns{toDelete}.idx(1), patterns{toDelete}.idx(2)];
            traceList = unique(userToDelete(:, 1));
            for it = 1:length(traceList)
              nlist = find(userToDelete(:, 1) == traceList(it));
              experiment.learningEventListPerTrace{traceList(it)}(userToDelete(nlist, 2)) = [];
            end
          end
          if(strcmpi(patterns{toDelete}.type, 'bursts'))
            %importedToDelete = patterns{toDelete}.idx;
            %currPatterns = experiment.burstPatterns.(field){idx};
            logMsg('Event simplification for bursts �s not implemented', 'w');
            break;
          end
          patterns(toDelete) = [];
          patternsRemoved = patternsRemoved + 1;
          logMsg(sprintf('Patterns %s and %s are very similar', px.name, py.name));
          break;
        end
      end
      if(~done)
        break;
      end
    end
  end
  logMsg(sprintf('%d patterns were removed', patternsRemoved));
  
  updatePatternTree();
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%--------------------------------------------------------------------------
function updateImage()

end

%--------------------------------------------------------------------------
function updateShowGroups(checkedPatterns)
  cla(hs.mainWindowFramesAxes);
  axis tight;
  xlabel('time (s)');
  ylabel('Normalized fluroescence');
  %set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
  box on;
  hold on;
  legend('off');
  nameList = {};
  h = [];
  cmap = parula(length(checkedPatterns)+1);
  for it = 1:length(checkedPatterns)
    currentPattern = patterns{checkedPatterns{it}};
    h = [h; plot(hs.mainWindowFramesAxes, currentPattern.t, (currentPattern.F-min(currentPattern.F))/(max(currentPattern.F)-min(currentPattern.F)), 'Color', cmap(it, :))];
    nameList{end+1} = currentPattern.fullName;
  end
  
  if(~isempty(nameList))
    %axes(hs.mainWindowFramesAxes);
    legend(hs.mainWindowFramesAxes,nameList);
    %legend('a')
  else
    legend('off');
  end
  %set(hs.mainWindowFramesAxes
  updateImage();
end

%--------------------------------------------------------------------------
function cleanMenu()
  a = findall(gcf);
  b = findall(a, 'ToolTipString', 'Save Figure');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Show Plot Tools');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Hide Plot Tools');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Open File');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'New Figure');
  set(b,'Visible','Off');
  %b = findall(a, 'ToolTipString', 'Insert Legend');
  %set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Insert Colorbar');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Data Cursor');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Rotate 3D');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Edit Plot');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Print Figure');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Brush/Select Data');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Link Plot');
  set(b,'Visible','Off');
  b = findall(a, 'ToolTipString', 'Show Plot Tools and Dock Figure');
  set(b,'Visible','Off');
end



%--------------------------------------------------------------------------
function updatePatternTree(~, ~)
  cla(hs.mainWindowFramesAxes);
  axis tight;
  xlabel('time (s)');
  ylabel('Normalized fluroescence');
  %set(hs.mainWindowFramesAxes, 'LooseInset', [0,0,0,0]);
  box on;
  hold on;
  
  import uiextras.jTree.*;
  if(isempty(patterns))
    [patterns, basePatternList] = generatePatternList(experiment, mode);
  end
  
  if(~isempty(patternTree))
    if(isprop(patternTree, 'Root'))
      delete(patternTree.Root)
    end
    delete(patternTree)
  end
   if(~isempty(patternTreeContextMenu))
    delete(patternTreeContextMenu)
  end
  if(~isempty(patternTreeContextMenuRoot))
    delete(patternTreeContextMenuRoot)
  end
  
  patternTree = uiextras.jTree.CheckboxTree('Parent', hs.groupPanel, 'RootVisible', false);
  % Even tho it does nothing
  if(isunix && ~ismac)
    patternTree.FontName = 'Bitstream Vera Sans Mono';
  else
    patternTree.FontName = 'Courier New';
  end
  Icon1 = fullfile(matlabroot,'toolbox','matlab','icons','foldericon.gif');
  
  % Create the context menus
  patternTreeContextMenu = uicontextmenu('Parent', hFigW);
  uimenu(patternTreeContextMenu, 'Label', 'Change type', 'Callback', {@changeMethod, patternTree});
  uimenu(patternTreeContextMenu, 'Label', 'Change correlation threshold', 'Callback', {@changeThreshold, patternTree});
  uimenu(patternTreeContextMenu, 'Label', 'Change name', 'Callback', {@changeName, patternTree});
  uimenu(patternTreeContextMenu, 'Label', 'Delete', 'Callback', {@deleteMethod, patternTree}, 'Separator', 'on');
  
  patternTreeContextMenuRoot = uicontextmenu('Parent', hFigW);
  
  uimenu(patternTreeContextMenuRoot, 'Label', 'Check all', 'Separator', 'on', 'Callback', {@selectMethod, patternTree, 'all'});
  uimenu(patternTreeContextMenuRoot, 'Label', 'Check none', 'Callback', {@selectMethod, patternTree, 'none'});
  patternTree.Editable = false;
  %patternTree.SelectionType = 'discontiguous';
  patternTree.SelectionType = 'single';
  
  % Create the nodes
  nodeGlobalIdx = 1;
  for i = 1:length(basePatternList)
    groupNode = uiextras.jTree.CheckboxTreeNode('Name', basePatternList{i}, 'TooltipString', basePatternList{i}, 'Parent', patternTree.Root);
    %groupNode.UserData = {basePatternList{i}, nodeGlobalIdx};
    nodeGlobalIdx = nodeGlobalIdx + 1;
    set(groupNode, 'UIContextMenu', patternTreeContextMenu)
    
    setIcon(groupNode, Icon1);
    groupMembers = find(cellfun(@(x)strcmpi(x.basePattern, basePatternList{i}), patterns));
    for j = 1:length(groupMembers)
      fullString = patterns{groupMembers(j)}.name;
      groupMemberNode = uiextras.jTree.CheckboxTreeNode('Name', fullString, 'TooltipString', fullString, 'Parent', groupNode);
      groupMemberNode.UserData = groupMembers(j);
      nodeGlobalIdx = nodeGlobalIdx + 1;
      set(groupMemberNode, 'UIContextMenu', patternTreeContextMenu)
    end
  end
   
  set(patternTree, 'UIContextMenu', patternTreeContextMenuRoot);
  patternTree.CheckboxClickedCallback = @checkedMethod;
  patternTree.SelectionChangeFcn = @selectedMethod;
   
  % Now the callbacks
  %------------------------------------------------------------------------
  function selectedMethod(hObject, edata)
    if(length(edata.Nodes) ~= 1 ||  isempty(edata.Nodes(1).UserData))
      return;
    end
    try
      printPatternInfo(patterns{edata.Nodes(1).UserData});
    catch
      printPatternInfo([]);
    end
    %printSavedExperimentInfo(experimentFile);
    %setappdata(netcalMainWindow, 'project', project);
    %updateMenu();
  end
  
  %------------------------------------------------------------------------
  function checkedMethod(hObject, ~)
    checkedList = {};
    % If root is selected is because all nodes are selected
    if(length(hObject.CheckedNodes) == 1 && strcmp(hObject.CheckedNodes.Name, 'Root'))
      checkedNodes = hObject.Root.Children;
    else
      checkedNodes = hObject.CheckedNodes;
    end
    for i = 1:length(checkedNodes)
      if(~isempty(checkedNodes(i).Children))
        for j = 1:length(checkedNodes(i).Children)
          checkedList{end+1} = checkedNodes(i).Children(j).UserData;
        end
      else
        checkedList{end+1} = checkedNodes(i).UserData;
      end
    end
    updateShowGroups(checkedList);
  end
  %------------------------------------------------------------------------
  function changeName(~, ~, handle)
    
    if(length(handle.CheckedNodes) == 1 && strcmpi(handle.CheckedNodes.Name, 'root'))
      nodeList = handle.CheckedNodes.Children;
    else
      nodeList = handle.CheckedNodes;
    end
        
    for it1 = 1:length(nodeList)
      % If its a whole group
      if(~isempty(nodeList(it1).Children))
        for it2 = 1:length(nodeList(it1).Children)
          nodeIdx = nodeList(it1).Children(it2).UserData;
          % Change from selected to checked
            answer = inputdlg(sprintf('Select the new name for pattern %s', patterns{nodeIdx}.fullName), 'New name', [1 60], {patterns{nodeIdx}.name});
            if(isempty(answer))
              return;
            end
            newName = answer{1};
          patterns{nodeIdx}.name = newName;
          % Find the original pattern and change it
          switch patterns{nodeIdx}.type
            case 'auto'
              experiment.patternFeatures{patterns{nodeIdx}.idx}.name = newName;
            case 'imported'
              experiment.importedPatternFeatures{patterns{nodeIdx}.idx}.name = newName;
            case 'importedBursts'
              experiment.importedBurstPatternFeatures{patterns{nodeIdx}.idx}.name = newName;
            case 'user'
              experiment.learningEventListPerTrace{patterns{nodeIdx}.idx(1)}{patterns{nodeIdx}.idx(2)}.name = newName;
            case 'bursts'
              experiment.burstPatterns.(patterns{nodeIdx}.idx{1}){patterns{nodeIdx}.idx{2}}{patterns{nodeIdx}.idx{3}}.name = newName;
              
          end
        end
        % Else, its a single node
      else
        nodeIdx = nodeList(it1).UserData;
        % Change from selected to checked
        answer = inputdlg(sprintf('Select the new name for pattern %s', patterns{nodeIdx}.fullName), 'New name', [1 60], {patterns{nodeIdx}.name});
        if(isempty(answer))
          return;
        end
        newName = answer{1};
        patterns{nodeIdx}.name = newName;
        % Find the original pattern and change it
        switch patterns{nodeIdx}.type
            case 'auto'
              experiment.patternFeatures{patterns{nodeIdx}.idx}.name = newName;
            case 'imported'
              experiment.importedPatternFeatures{patterns{nodeIdx}.idx}.name = newName;
            case 'importedBursts'
              experiment.importedBurstPatternFeatures{patterns{nodeIdx}.idx}.name = newName;
            case 'user'
              experiment.learningEventListPerTrace{patterns{nodeIdx}.idx(1)}{patterns{nodeIdx}.idx(2)}.name = newName;
            case 'bursts'
              experiment.burstPatterns.(patterns{nodeIdx}.idx{1}){patterns{nodeIdx}.idx{2}}{patterns{nodeIdx}.idx{3}}.name = newName;
        end
      end
    end
    [patterns, basePatternList] = generatePatternList(experiment, mode);
    updatePatternTree();
  end
  %------------------------------------------------------------------------
  function changeThreshold(~, ~, handle)
    % Change from selected to checked
    answer = inputdlg('Select the new correlation threshold (applies to ALL checked patterns)', 'New type', [1 60], {'0.9'});
    if(isempty(answer))
      return;
    end
    newThreshold = str2double(answer{1});
    
    if(length(handle.CheckedNodes) == 1 && strcmpi(handle.CheckedNodes.Name, 'root'))
      nodeList = handle.CheckedNodes.Children;
    else
      nodeList = handle.CheckedNodes;
    end
        
    for it1 = 1:length(nodeList)
      % If its a whole group
      if(~isempty(nodeList(it1).Children))
        for it2 = 1:length(nodeList(it1).Children)
          nodeIdx = nodeList(it1).Children(it2).UserData;
          patterns{nodeIdx}.threshold = newThreshold;
          % Find the original pattern and change it
          switch patterns{nodeIdx}.type
            case 'auto'
              experiment.patternFeatures{patterns{nodeIdx}.idx}.threshold = newThreshold;
            case 'imported'
              experiment.importedPatternFeatures{patterns{nodeIdx}.idx}.threshold = newThreshold;
            case 'importedBursts'
              experiment.importedBurstPatternFeatures{patterns{nodeIdx}.idx}.threshold = newThreshold;
            case 'user'
              experiment.learningEventListPerTrace{patterns{nodeIdx}.idx(1)}{patterns{nodeIdx}.idx(2)}.threshold = newThreshold;
            case 'bursts'
              experiment.burstPatterns.(patterns{nodeIdx}.idx{1}){patterns{nodeIdx}.idx{2}}{patterns{nodeIdx}.idx{3}}.threshold = newThreshold;
              
          end
        end
        % Else, its a single node
      else
        nodeIdx = nodeList(it1).UserData;
        patterns{nodeIdx}.threshold = newThreshold;
        switch patterns{nodeIdx}.type
          case 'auto'
            experiment.patternFeatures{patterns{nodeIdx}.idx}.threshold = newThreshold;
          case 'imported'
            experiment.importedPatternFeatures{patterns{nodeIdx}.idx}.threshold = newThreshold;
          case 'importedBursts'
            experiment.importedBurstPatternFeatures{patterns{nodeIdx}.idx}.threshold = newThreshold;
          case 'user'
            experiment.learningEventListPerTrace{patterns{nodeIdx}.idx(1)}{patterns{nodeIdx}.idx(2)}.threshold = newThreshold;
          case 'bursts'
            experiment.burstPatterns.(patterns{nodeIdx}.idx{1}){patterns{nodeIdx}.idx{2}}{patterns{nodeIdx}.idx{3}}.threshold = newThreshold;
        end
      end
    end
    [patterns, basePatternList] = generatePatternList(experiment, mode);
    updatePatternTree();
  end
  
  %------------------------------------------------------------------------
  function changeMethod(~, ~, handle)
    % Change from selected to checked
    answer = inputdlg('Select the new type (applies to ALL checked patterns)', 'New tpye', [1 60],{basePatternList{1}});
    if(isempty(answer))
      return;
    end
    newPattern = answer{1};
    
    if(length(handle.CheckedNodes) == 1 && strcmpi(handle.CheckedNodes.Name, 'root'))
      nodeList = handle.CheckedNodes.Children;
    else
      nodeList = handle.CheckedNodes;
    end
    
    for it1 = 1:length(nodeList)
      % If its a whole group
      if(~isempty(nodeList(it1).Children))
        for it2 = 1:length(nodeList(it1).Children)
          nodeIdx = nodeList(it1).Children(it2).UserData;
          patterns{nodeIdx}.basePattern = newPattern;
          % Find the original pattern and change it
          switch patterns{nodeIdx}.type
            case 'auto'
              experiment.patternFeatures{patterns{nodeIdx}.idx}.basePattern = newPattern;
            case 'imported'
              experiment.importedPatternFeatures{patterns{nodeIdx}.idx}.basePattern = newPattern;
            case 'importedBursts'
              experiment.importedBurstPatternFeatures{patterns{nodeIdx}.idx}.basePattern = newPattern;
            case 'user'
              experiment.learningEventListPerTrace{patterns{nodeIdx}.idx(1)}{patterns{nodeIdx}.idx(2)}.basePattern = newPattern;
            case 'bursts'
              experiment.burstPatterns.(patterns{nodeIdx}.idx{1}){patterns{nodeIdx}.idx{2}}{patterns{nodeIdx}.idx{3}}.basePattern = newPattern;
          end
        end
        % Else, its a single node
      else
        nodeIdx = nodeList(it1).UserData;
        patterns{nodeIdx}.basePattern = newPattern;
        switch patterns{nodeIdx}.type
          case 'auto'
            experiment.patternFeatures{patterns{nodeIdx}.idx}.basePattern = newPattern;
          case 'imported'
            experiment.importedPatternFeatures{patterns{nodeIdx}.idx}.basePattern = newPattern;
          case 'importedBursts'
            experiment.importedBurstPatternFeatures{patterns{nodeIdx}.idx}.basePattern = newPattern;
          case 'user'
            experiment.learningEventListPerTrace{patterns{nodeIdx}.idx(1)}{patterns{nodeIdx}.idx(2)}.basePattern = newPattern;
          case 'bursts'
            experiment.burstPatterns.(patterns{nodeIdx}.idx{1}){patterns{nodeIdx}.idx{2}}{patterns{nodeIdx}.idx{3}}.basePattern = newPattern;
        end
      end
    end
    [patterns, basePatternList] = generatePatternList(experiment, mode);
    updatePatternTree();
  end
  
  %------------------------------------------------------------------------
  function deleteMethod(~, ~, handle)
    % First do a rapid count on the selected nodes and ask for confirmation
    numSelectedNodes = 0;
    
    if(length(handle.CheckedNodes) == 1 && strcmpi(handle.CheckedNodes.Name, 'root'))
      nodeList = handle.CheckedNodes.Children;
    else
      nodeList = handle.CheckedNodes;
    end
    
    for it1 = 1:length(nodeList)
      % If its a whole group
      if(~isempty(nodeList(it1).Children))
        numSelectedNodes = numSelectedNodes + length(nodeList(it1).Children);
      % Else, its a single node
      else
        numSelectedNodes = numSelectedNodes + 1;
      end
    end
    msg = sprintf('Are you sure you want to delete all %d checked patterns?', numSelectedNodes);
    choice = questdlg(msg, 'Delete patterns', ...
                       'Yes', 'No', 'Cancel', 'Cancel');
    switch choice
      case 'Yes'
      otherwise
        return;
    end
    
    % Now the real deletion
    autoToDelete = [];
    userToDelete = [];
    importedToDelete = [];
    importedBurstToDelete = [];
    burstsToDelete = {};
    for it1 = 1:length(nodeList)
      % If its a whole group
      if(~isempty(nodeList(it1).Children))
        for it2 = 1:length(nodeList(it1).Children)
          nodeIdx = nodeList(it1).Children(it2).UserData;
          % Find the original pattern and delete it
          if(isempty(nodeIdx))
            continue;
          end
          switch patterns{nodeIdx}.type
            case 'auto'
              autoToDelete = [autoToDelete; patterns{nodeIdx}.idx];
            case 'imported'
              importedToDelete = [importedToDelete; patterns{nodeIdx}.idx];
            case 'importedBursts'
              importedBurstToDelete = [importedBurstToDelete; patterns{nodeIdx}.idx];
            case 'user'
              userToDelete = [userToDelete; patterns{nodeIdx}.idx(1), patterns{nodeIdx}.idx(2)];
            case 'bursts'
              burstsToDelete{end+1} = patterns{nodeIdx}.idx;
          end
        end
        % Else, its a single node
      else
        nodeIdx = nodeList(it1).UserData;
        switch patterns{nodeIdx}.type
          case 'auto'
            autoToDelete = [autoToDelete; patterns{nodeIdx}.idx];
          case 'imported'
            importedToDelete = [importedToDelete; patterns{nodeIdx}.idx];
            case 'importedBursts'
            importedBurstToDelete = [importedBurstToDelete; patterns{nodeIdx}.idx];
          case 'user'
            userToDelete = [userToDelete; patterns{nodeIdx}.idx(1), patterns{nodeIdx}.idx(2)];
          case 'bursts'
            burstsToDelete{end+1} = patterns{nodeIdx}.idx;
        end
      end
    end
    if(~isempty(autoToDelete))
      autoToDelete = unique(autoToDelete);
      experiment.patternFeatures(autoToDelete) = [];
    end
    if(~isempty(importedToDelete))
      importedToDelete = unique(importedToDelete);
      experiment.importedPatternFeatures(importedToDelete) = [];
    end
    if(~isempty(importedBurstToDelete))
      importedBurstToDelete = unique(importedBurstToDelete);
      experiment.importedBurstPatternFeatures(importedBurstToDelete) = [];
    end
    if(~isempty(userToDelete))
      traceList = unique(userToDelete(:, 1));
      for it = 1:length(traceList)
        nlist = find(userToDelete(:, 1) == traceList(it));
        experiment.learningEventListPerTrace{traceList(it)}(userToDelete(nlist, 2)) = [];
      end
    end
    if(~isempty(burstsToDelete))
      % Let's go backwards and hope for the best - Doesn't really work
      % Create a list of indexes
      idxList1 = {};
      idxList2 = [];
      for it = 1:length(burstsToDelete)
        idxList1 = unique([idxList1; burstsToDelete{it}{1}]);
        idxList2 = unique([idxList2; burstsToDelete{it}{2}]);
      end
      % Now the triple loop
      for it1 = 1:length(idxList1)
        for it2 = 1:length(idxList2)
          valid = [];
          for it = 1:length(burstsToDelete)
            if(strcmp(burstsToDelete{it}{1}, idxList1{it1}) && burstsToDelete{it}{2} == idxList2(it2))
              valid = [valid; it];
            end
          end
            % Now backward removal
          for it = length(valid):-1:1
            experiment.burstPatterns.(burstsToDelete{valid(it)}{1}){burstsToDelete{valid(it)}{2}}(burstsToDelete{valid(it)}{3}) = [];
          end
        end
      end
    end
    [patterns, basePatternList] = generatePatternList(experiment, mode);
    updatePatternTree();
  end
  
  %------------------------------------------------------------------------
  function selectMethod(hObject, eventData, handle, mode)
    switch mode
      case 'all'
        handle.Root.Checked = true;
      case 'none'
      handle.Root.Checked = true;
      handle.Root.Checked = false;
    end
  end
end

%--------------------------------------------------------------------------
function printPatternInfo(varargin)
  if(nargin < 1)
    pattern = [];
  else
    pattern = varargin{1};
  end
  hlog = hs.infoPanelEditBox;
  logMessage(hlog, 'clear');
  if(isempty(pattern))
    logMessage(hlog, 'No pattern selected');
  else
    %logMessage(hlog, sprintf('Name: %s', pattern.name));
    logMessage(hlog, sprintf('Full name: %s', pattern.fullName));
    %logMessage(hlog, sprintf('base pattern: %s', pattern.basePattern));
    logMessage(hlog, sprintf('Type: %s', pattern.type));
    logMessage(hlog, sprintf('Duration: %.2f s', length(pattern.t)/experiment.fps));
    logMessage(hlog, sprintf('Threshold: %.2f', pattern.threshold));
  end
  
end

end


