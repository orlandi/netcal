function [success, optionsObject] = optionsWindow(optionsObject, varargin)
% OPTIONSWINDOW window used to change parameters from a baseOptions class
%
% USAGE:
%   [success, parameters] = optionsWindow(parameters, windowTitle)
%
% INPUT arguments:
%   parameters - baseOptions derived class containing the options
%
% INPUT optional arguments: 
%   windowTitle - The window title. If missing it will use the first line
%   returned from calling help on the parameters class (starting at the
%   second word)
%
% OUTPUT arguments:
%   success - Returns true only if the OK button is pressed (true/false)
%
%   parameters - New set of parameters
%
% EXAMPLE:
%   [success, parameters] = optionsWindow(baseOptions, 'Simple window')
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% This function is derived from the original propertiesGUI from
% Yair M. Altman http://undocumentedmatlab.com/blog/propertiesgui
%
% License to use and modify this code is granted freely to all interested, as long as the original author is
% referenced and attributed as such. The original author maintains the right to be solely associated with this work.
% Programmed and Copyright by Yair M. Altman: altmany(at)gmail.com
% $Revision: 1.15 $  $Date: 2015/03/12 12:37:46 $

params.windowTitle = [];
params.type = 'modal'; % modal/nonmodal
params.parent = [];
params.parentType = 'primary';
params.experiment = [];
params.isEditable = true;
params.project = [];
params = parse_pv_pairs(params, varargin);

% Redefine some names
parent = params.parent;
windowTitle = params.windowTitle;
isEditable = params.isEditable;
dummy = false;
success = false;

% If no options are passed but the parent exist. Create it dummy mode (so
% it can be attached to the GUI)
if(isempty(optionsObject) && ~isempty(parent))
  optionsObject = baseOptions;
  dummy = true;
elseif(isempty(optionsObject) || ~isa(optionsObject, 'baseOptions'))
  return;
end

%%% -----------------------------------------------------------------------
%%% Set default properties
%%% -----------------------------------------------------------------------
% Set default values to the class

optionsObject = optionsObject.setDefaults();

% Create a copy of the original class object with its defaults
mainClass = class(optionsObject);
originalClassObject = eval(mainClass);
originalClassObject = originalClassObject.setDefaults();
% Set experiment defaults if it still hold the original values
if(~isempty(params.experiment) && isequaln(optionsObject, originalClassObject))
  optionsObject = optionsObject.setExperimentDefaults(params.experiment);
end
% Set project defaults if it still hold the original values
if(~isempty(params.project) && isequaln(optionsObject, originalClassObject))
  optionsObject = optionsObject.setProjectDefaults(params.project);
end
% Turn the options into a struct for better handling
optionsStruct = optionsObject.get();
originalOptionsStruct = optionsStruct;


% Now we pass the default class parameters for everything
classObjectDefaults = eval(mainClass);
if(~isempty(params.experiment))
  classObjectDefaults = classObjectDefaults.setExperimentDefaults(params.experiment);
end
if(~isempty(params.project))
  classObjectDefaults = classObjectDefaults.setProjectDefaults(params.project);
end
structObjectDefaults = classObjectDefaults.get();

optionsStruct = structObjectDefaults;




%%% -----------------------------------------------------------------------
%%% Prepare HELP data
%%% -----------------------------------------------------------------------
% Let's define the window title based on the help file if it doesn't exist
if(isempty(windowTitle))
  fullHelp = strsplit(strtrim(help(mainClass)), '\n');
  firstHelpLine = strsplit(fullHelp{1});
  windowTitle = strtrim(strrep(strjoin(firstHelpLine(2:end)),'#', ''));
end
% Let's get the files of the superclasses to generate all the help data
classFile = which(mainClass);
superClassList = superclasses(mainClass);
superClassListFiles = cellfun(@(x)which(x), superClassList, 'UniformOutput', false);

[classFolder, ~, ~] = fileparts(classFile);
helpFile = [classFolder filesep 'help' filesep mainClass '.md'];

if(exist(helpFile, 'file'))
  helpText = fileread(helpFile);
else
  try
    helpText = generateAutomaticHelpFile(classFile);
    for it = 1:length(superClassListFiles)
      helpText = sprintf('%s\n%s', helpText, generateAutomaticHelpFile(superClassListFiles{it}, false));
    end
    % Need to go through subclasses
  catch
    helpText = {'# Help'; 'Not available'};
  end
end
% Get the descriptions of the class so we can use it for the help info
fnames = fieldnames(optionsStruct);
parametersDescriptions = cell(size(fnames));
for it = 1:length(fnames)
  % So ugly
  parametersDescriptions{it} = strtrim(help([mainClass '.' fnames{it}]));
  inherited = strfind(parametersDescriptions{it}, 'Help for');
  % Trim inheritance text
  if(~isempty(inherited) && inherited > 1)
      parametersDescriptions{it} = parametersDescriptions{it}(1:(inherited-1));
  end
end

%%% -----------------------------------------------------------------------
%%% Prepare the actual window
%%% -----------------------------------------------------------------------
% Init JIDE
com.mathworks.mwswing.MJUtilities.initJIDE;

% Get the warnings off
originalWarn = warning('off','MATLAB:hg:JavaSetHGProperty');
warning off MATLAB:hg:PossibleDeprecatedJavaSetHGProperty

% Now props are assigned and default parameters returned
[propsList, ~] = preparePropsList(optionsStruct, parametersDescriptions, isEditable);
optionsStruct = updatePropsList(propsList, originalOptionsStruct);

% Create a mapping propName => prop
propsHash = java.util.Hashtable;
propsArray = propsList.toArray();
for propsIdx = 1:length(propsArray)
  curProp = propsArray(propsIdx);
  propName = getPropName(curProp);
  propsHash.put(propName, curProp);
end
warning(originalWarn);

% Prepare a properties table that contains the list of properties
model = javaObjectEDT(com.jidesoft.grid.PropertyTableModel(propsList));
model.expandAll();

% Prepare the properties table (grid)
grid = javaObjectEDT(com.jidesoft.grid.PropertyTable(model));
grid.setSelectedProperty(propsArray(1))
grid.setShowNonEditable(grid.SHOW_NONEDITABLE_BOTH_NAME_VALUE);
%set(handle(grid.getSelectionModel,'CallbackProperties'), 'ValueChangedCallback', @propSelectedCallback);

com.jidesoft.grid.TableUtils.autoResizeAllColumns(grid);
grid.setRowHeight(25);  % default=16; autoResizeAllRows=20 - we need something in between

% Auto-end editing upon focus loss
grid.putClientProperty('terminateEditOnFocusLost',true);

% If no parent (or the root) was specified

% Create a new figure window
if(~isempty(parent))
  % Make sure parent is empty
  delete(parent.Children)
end
delete(findall(0, '-depth', 1, 'Tag', 'fpropertiesGUI'));

if(~isempty(gcbf))
  gui = gcbf;
else
  gui = [];
end

% Create the actualf igure if needed
if(isempty(parent))
  hFig = figure('NumberTitle','off', ...
                'Name', windowTitle, ...
                'Units','pixel', ...
                'Menu','none', ...
                'KeyPressFcn', @KeyPress, ...
                'Toolbar','none', ...
                'Tag','fpropertiesGUI', ...
                'Visible','off');
  hFig.Position = setFigurePosition(gui, 'width', 500, 'height', 500);
else
  hFig = parent;
  gui = ancestor(hFig, 'Figure');
end

% Create the panels and such
%--------------------------------------------------------------------------
hs.mainWindowGrid = uix.HBox('Parent', hFig);

% First column (panel and buttons)
%--------------------------------------------------------------------------
% Set a Vbox
hs.mainWindowLeftPane = uix.VBox('Parent', hs.mainWindowGrid);
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowLeftPane, 'Padding', 5, 'BorderType', 'none');
hs.mainWindowBottomButtons = uix.HBox( 'Parent', hs.mainWindowLeftPane);

% Add the bottom action buttons
if(strcmpi(params.type, 'nonmodal') && isempty(parent))
  btOK     = uicontrol('Parent', hs.mainWindowBottomButtons, 'String','Apply', 'Tag','btOK',     'Callback',@btOK_Callback);
  btCancel = uicontrol('Parent', hs.mainWindowBottomButtons, 'String','Close', 'Tag','btCancel', 'Callback',@(h,e)close(hFig)); %#ok<NASGU>
elseif(isempty(parent))
  btOK     = uicontrol('Parent', hs.mainWindowBottomButtons, 'String','OK', 'Tag','btOK',     'Callback',@btOK_Callback);
  btCancel = uicontrol('Parent', hs.mainWindowBottomButtons, 'String','Cancel', 'Tag','btCancel', 'Callback',@(h,e)close(hFig)); %#ok<NASGU>
end
uix.Empty('Parent', hs.mainWindowBottomButtons);
btDefaults = uicontrol('Parent', hs.mainWindowBottomButtons, 'String','Defaults', 'Tag','btDefaults', 'Callback',{@btDefaults_Callback, mainClass, propsList}); %#ok<NASGU>

btHelp = uicontrol('Style', 'togglebutton', 'Parent', hs.mainWindowBottomButtons, 'String', 'Help', 'Tag', 'btHelp');

if(isempty(parent))
  set(hs.mainWindowBottomButtons, 'Widths', [100 100 -1 100 100], 'Padding', 5, 'Spacing', 5);
  set(hs.mainWindowLeftPane, 'Heights', [-1 50]);
else
  uix.Empty('Parent', hs.mainWindowBottomButtons);
  set(hs.mainWindowBottomButtons, 'Widths', [-1 80 80 -1], 'Padding', 5, 'Spacing', 5);
  set(hs.mainWindowLeftPane, 'Heights', [-1 35]);
end

% Second column (empty for now)
%--------------------------------------------------------------------------
% De help
if(isempty(parent))
  helpPanel = MarkdownPanel('Parent', hs.mainWindowGrid);
  set(helpPanel, 'Content', helpText);
  btHelp.Callback = {@btHelp_Callback, helpPanel};
  set(hs.mainWindowGrid, 'Widths', [-1 0]);
else
  btHelp.Callback = {@btHelp_CallbackStandalone, classFile, helpFile, superClassListFiles};
  set(hs.mainWindowGrid, 'Widths', -1);
end

% Finish the grid
%--------------------------------------------------------------------------

% Check the property values to determine whether the <OK> button should be enabled or not
%if(isempty(parent))
  %checkProps(propsList, btOK, true);
%end

% Make visible and modal if needed
if(strcmpi(params.type, 'modal') && isempty(parent))
  set(hFig, 'WindowStyle','modal');
end
set(hFig, 'Visible','on');


if(ishandle(hs.mainWindowFramesPanel))
  hFigPos = getpixelposition(hs.mainWindowFramesPanel);
  pos = [5,5,hFigPos(3)-10,hFigPos(4)-10];
else
  return;
end
pane = javaObjectEDT(com.jidesoft.grid.PropertyPane(grid));
customizePropertyPane(pane);
[jPropsPane, hPropsPane_] = javacomponent(pane, pos, hs.mainWindowFramesPanel);

% A callback for touching the mouse
hgrid = handle(grid, 'CallbackProperties');
if(isempty(parent))
  set(hgrid, 'MousePressedCallback', {@MousePressedCallback, hFig});
  setappdata(hFig, 'jPropsPane', jPropsPane);
  setappdata(hFig, 'propsList', propsList);
  setappdata(hFig, 'mirror', optionsStruct);
else
  set(hgrid, 'MousePressedCallback', {@MousePressedCallback, gui});
  setappdata(gui, 'jPropsPane', jPropsPane);
  setappdata(gui, 'propsList', propsList);
  setappdata(gui, 'mirror', optionsStruct);
end

if(~isempty(parent))
  hFig = gui;
  params.type = 'nonmodal';
end
set(hPropsPane_, 'tag', 'hpropertiesGUI');
set(hPropsPane_, 'Units', 'norm');

%%%------------------------------------------------------------------------
%%% Finish initialization
%%%------------------------------------------------------------------------

% Align the background colors
bgcolor = pane.getBackground.getComponents([]);
try 
  set(hFig, 'Color', bgcolor(1:3));
catch
end
try 
  pane.setBorderColor(pane.getBackground);
catch
end  % error reported by Andrew Ness

updateParamsClass();

% If a new figure was created, make it modal and wait for user to close it
if(~isempty(parent))
  % If the help window is open, update it
  if(~isempty(findall(0, '-depth',1, 'Tag','fpropertiesGUIhelp')))
    btHelp_CallbackStandalone([], [], classFile, helpFile, superClassListFiles);
  end
end

%%% TEST
% for it = 0:(size(propsList)-1)
%   pProp = propsList.get(it);
%   pProp.getDisplayName
% end

% if(isempty(parent))
%   checkProps(propsList, btOK, false); % Always on
% end

if(~isempty(parent) && dummy)
  parent.Visible = 'off';
end

if(isempty(parent))
  refresh(hFig);
end

if(strcmpi(params.type, 'nonmodal'))
  return;
end

if(isempty(parent))
  uiwait(hFig);
end

%%%------------------------------------------------------------------------
%%% Closing window
%%%------------------------------------------------------------------------

if(ishandle(hFig))
  optionsStruct = fixFields(optionsStruct);
  optionsObject = optionsObject.set(optionsStruct);

  close(hFig);
  success = true;
else
  optionsObject = [];
end

try
  close(hFig);
catch
  delete(hFig);  % force-close
end

  %%%------------------------------------------------------------------------
  %%% Internal callbacks
  %%%------------------------------------------------------------------------

  % Default callback function to set defaults
  %------------------------------------------------------------------------
  function btDefaults_Callback(btOK, eventData, mainClass, propsList)
    defaultsClassObject = eval(mainClass);
    defaultsClassObject = defaultsClassObject.setDefaults();
    if(~isempty(params.experiment))
      defaultsClassObject = defaultsClassObject.setExperimentDefaults(params.experiment);
    end
    if(~isempty(params.project))
      defaultsClassObject = defaultsClassObject.setProjectDefaults(params.project);
    end
    defaultsStructObject = defaultsClassObject.get();
    
    optionsStruct = updatePropsList(propsList, defaultsStructObject);

  end

  % Subfunctions to set properties - I believe that's quite redundant (botch)
  %------------------------------------------------------------------------
  function structObject = updatePropsList(propsList, structObject)
     % And update the entries
    for i = 0:(size(propsList)-1)
      curPropb = propsList.get(i);
      propNameb = getRecursivePropName(curPropb); % get the property name
      if(iscell(structObject.(propNameb)) && size(structObject.(propNameb), 2) == 1)
        [newValue, successDef] = setArrayProperty(structObject, propNameb, curPropb);
        if(successDef)
          curPropb.setValue(newValue);
          % Don't update contents with the name
        end
      elseif(iscell(structObject.(propNameb))&& size(structObject.(propNameb), 2) ~= 1)
        % If we are here, something is wrong. Reassign values
        [newValue, successDef] = setDefaultCellProperty(structObject, propNameb, curPropb);
        if(successDef)
          curPropb.setValue(newValue);
          structObject.(propNameb) = newValue;
        end
      elseif(isstruct(structObject.(propNameb)))
         [~, ~] = setStructProperty(structObject, propNameb, curPropb);
         % We don't update the root of the structure
      else
        [newValue, successDef] = setDefaultProperty(structObject, propNameb, curPropb);
        if(successDef)
          curPropb.setValue(newValue);
          structObject.(propNameb) = newValue;
        end
      end
    end
  end

  %------------------------------------------------------------------------
  function [newValue, success] = setStructProperty(defStruct, propName, curProp)
    newStruct = defStruct.(propName);
    chl = curProp.getChildrenCount;
    fields = fieldnames(newStruct);
    %defStruct.(propName) = newStruct;
    for itt = 1:chl
      ch = curProp.getChildAt(itt-1);
      subName = ch.getName.toCharArray;
      subName = subName(:)';
      foundField = find(strcmpi(fields, subName));
      if(~isempty(foundField))
        newVall = newStruct.(fields{foundField});
        newProp = ch;
        newPropName = fields{foundField};
        % Now same comparisons as always
        if(iscell(newVall) && size(newVall, 2) == 1)
          [newValue, success] = setArrayProperty(newStruct, fields{foundField}, ch);
          if(success)
            newProp.setValue(newValue);
          end
        elseif(iscell(newVall) && size(newVall, 2) ~= 1)
          % If we are here, something is wrong. Reassign values
          [newValue, success] = setDefaultCellProperty(newStruct, fields{foundField}, ch);
          if(success)
            newProp.setValue(newValue);
            newStruct.(newPropName) = newValue;
          end
        elseif(isstruct(newVall))
          [~, ~] = setStructProperty(newStruct, fields{foundField}, ch);
        else
          [newValue, success] = setDefaultProperty(newStruct, fields{foundField}, ch);
          if(success)
            newProp.setValue(newValue);
            newStruct.(newPropName) = newValue;
          end
        end
      end
    end
  end

  %----------------------------------------------------------------------
  function [newValue, success] = setDefaultProperty(defStruct, propName, ~)
    success = true;
    newValue = defStruct.(propName);
    if(isnumeric(newValue) && numel(newValue) > 1)
      %valueb = ['[' num2str(valueb) ']'];
      partval = strtrim(sprintf('%g, ', newValue));
      if(~isempty(partval))
        partval = partval(1:end-1);
      end
      newValue = ['[' partval ']'];
    end
  end

  %----------------------------------------------------------------------
  function [newValue, success] = setDefaultCellProperty(defStruct, propName, ~)
    success = true;
    newValue = defStruct.(propName);
    newValue = newValue{1};
  end

  %----------------------------------------------------------------------
  function [newValue, success] = setArrayProperty(defStruct, propName, curProp)
    newValue = [];
    success = false;
    arrayData = defStruct.(propName);
    if ~isempty(arrayData)
      try
        set(curProp,'arrayData',arrayData)
      catch
        schema.prop(handle(curProp),'arrayData','mxArray'); %#ok<NASGU>
        set(handle(curProp),'arrayData',arrayData)
      end
      curProp.setEditable(false);
      newValue = regexprep(sprintf('%dx',size(arrayData)),{'^(.)','x$'},{'<$1','> cell array'});
      success = true;
      %curProp.setValue(valueb);
      %defStruct.(propName) = valueb;
    end
  end
  
  % <OK> button callback function
  %------------------------------------------------------------------------
  function btOK_Callback(btOK, eventData) %#ok<INUSD>

    % If it's notnmodal it means it will remain open
    if(strcmpi(params.type, 'nonmodal'))
      optionsStruct = fixFields(optionsStruct);
      optionsObject = optionsObject.set(optionsStruct);
      
      if(~isempty(gui) && ~dummy)

        setappdata(gui, [mainClass 'Current'], optionsObject);
        setappdata(gui, 'updatedParameters', true);
        resizeHandle = getappdata(gui, 'ResizeHandle');
        if(isa(resizeHandle,'function_handle'))
          resizeHandle([], []);
        end
      else
        setappdata(0, [mainClass 'Current'], optionsObject);
      end
    else
      uiresume(hFig);
    end
  end



  %--------------------------------------------------------------------------
  function btHelp_Callback(btOk, ~, helpPanel)
    hFigb = btOk.Parent.Parent.Parent.Parent;
    hGrid = btOk.Parent.Parent.Parent;
    if(btOk.Value)
      hFigb.Position(3) = 2*hFigb.Position(3);
      set(helpPanel, 'Content', helpPanel.Content);
      set(hGrid, 'Widths', [-1 -1]);
    else
      hFigb.Position(3) = 1/2*hFigb.Position(3);
      set(hGrid, 'Widths', [-1 0]);
    end
  end

  %------------------------------------------------------------------------
  function btHelp_CallbackStandalone(~, ~, classFile, helpFile, superClassListFiles)
  
    % Delete any previous help function
    helpFig = findall(0, '-depth',1, 'Tag', 'fpropertiesGUIhelp');
    if(~isempty(helpFig))
      
      clf(helpFig);
    else
      helpFig = figure('NumberTitle','off', ...
                  'Name', 'Help', ...
                  'Units','pixel', ...
                  'Menu','none', ...
                  'Toolbar','none', ...
                  'Tag','fpropertiesGUIhelp', ...
                  'Visible','off');
      helpFig.Position = setFigurePosition(gui, 'width', 500, 'height', 500);
    end

    helpPanelStandAlone = MarkdownPanel('Parent', helpFig);
    if(exist(helpFile, 'file'))
      helpTextStandAlone = fileread(helpFile);
    else
      helpTextStandAlone = generateAutomaticHelpFile(classFile);
      for itt = 1:length(superClassListFiles)
        helpTextSuper = generateAutomaticHelpFile(superClassListFiles{itt}, false);
        helpTextStandAlone = sprintf('%s\n%s', helpTextStandAlone, helpTextSuper);
      end
      %helpText
      %helpText = {'# Help'; 'Not available (TODO)'};
    end
    set(helpPanelStandAlone, 'Content', helpTextStandAlone);
    helpFig.Visible = 'on';

    %timerFcn = @(s,e)set(helpPanelStandAlone, 'Content', char(helpPanelStandAlone.Content));
    htimer = timer( ...
                    'Period',        1, ...
                    'BusyMode',      'drop', ...
                    'TimerFcn',      {@basicTimerFcn, helpPanelStandAlone, char(helpPanelStandAlone.Content)}, ...
                    'ExecutionMode', 'fixedRate');

    % Destroy the timer when the panel is destroyed
    L = addlistener(helpPanelStandAlone, 'ObjectBeingDestroyed', @timerCallback);
    setappdata(helpFig, 'Timer', L);

    % Start the refresh timer
    start(htimer)
  
    %----------------------------------------------------------------------
    function basicTimerFcn(~, ~, panelObj, content)
      try
        set(panelObj, 'Content', content);
      catch
      end
    end
    
    %----------------------------------------------------------------------
    function timerCallback(tObj, ~)
      try
        stop(tObj);
        delete(tObj);
      catch
      end
   end
  end

  % Enter & Esc to quit the window
  %------------------------------------------------------------------------
  function KeyPress(hObject, eventData)
    switch eventData.Key
      case 'return'
        btOK_Callback(hObject, eventData);
      case 'escape'
        close(ancestor(hObject, 'figure'));
    end
  end

% Mouse-click callback function
  %------------------------------------------------------------------------
  function MousePressedCallback(grid, eventdata, hFig)
    % Get the clicked location
    clickX = eventdata.getX;
    clickY = eventdata.getY;

    if clickX <= 20  %leftColumn.getWidth % clicked the side-bar
      return;
    end
    % bail-out if right-click
    if ~eventdata.isMetaDown
      % bail-out if the grid is disabled
      if ~grid.isEnabled
        return;
      end

      selectedProp = grid.getSelectedProperty; % which property (java object) was selected
      if ~isempty(selectedProp)
        if ismember('arrayData',fieldnames(get(selectedProp)))
          % Get the current data and update it
          actualData = get(selectedProp,'ArrayData');
          updateDataInPopupTable(selectedProp.getName, actualData, hFig, selectedProp);
        end
      end
    end
  end %Mouse pressed

  % Update data in a popup table
  %------------------------------------------------------------------------
  function updateDataInPopupTable(titleStr, data, hGridFig, selectedProp)
    figTitleStr = [char(titleStr) ' data'];
    hFigb = findall(0, '-depth',1, 'Name', figTitleStr);
    if isempty(hFigb)
      hFigb = figure('NumberTitle','off', 'Name',figTitleStr, 'Menubar','none', 'Toolbar','none');
    else
      figure(hFigb);  % bring into focus
    end
    try
      mtable = createTable(hFigb, [], data);
      set(mtable,'DataChangedCallback',{@tableDataUpdatedCallback,hGridFig,selectedProp});
      uiwait(hFigb)  % modality
    catch
      delete(hFigb);
    end
  end  % updateDataInPopupTable

  %------------------------------------------------------------------------
  function tableDataUpdatedCallback(mtable,eventData,hFig,selectedProp) %#ok<INUSL>
    % Get the latest data
    updatedData = cell(mtable.Data);
    try
    if ~iscellstr(updatedData)
      updatedData = cell2mat(updatedData);
    end
    catch
    end

    propNameb = getRecursivePropName(selectedProp); % get the property name
    set(selectedProp,'ArrayData',updatedData); % update the appdata of the
    % specific property containing the actual information of the array

    % Update the displayed value in the properties GUI
    dataClass = class(updatedData);
    valueb = regexprep(sprintf('%dx',size(updatedData)),{'^(.)','x$'},{'<$1',['> ' dataClass ' array']});
    selectedProp.setValue(valueb); % update the table

    % Update the display
    propsListb = getappdata(hFig, 'propsList'); %#ok<NASGU>
    %checkProps(propsListb, hFig);

    % Refresh the GUI
    propsPane = getappdata(hFig, 'jPropsPane');
    try
      propsPane.repaint;
    catch
    end

    % Update the local mirror
    %data = getappdata(hFig, 'mirror');
    eval(['optionsStruct.' propNameb ' = updatedData;']);
    updateParamsClass();
  end


  %%%------------------------------------------------------------------------
  %%% Additional functions
  %%%------------------------------------------------------------------------
  
  % Customize the property-pane's appearance
  %------------------------------------------------------------------------
  function customizePropertyPane(pane)
    pane.setShowDescription(true);
    pane.setShowToolBar(false);
    pane.setOrder(2);  % uncategorized, unsorted - see http://undocumentedmatlab.com/blog/advanced-jide-property-grids/#comment-42057
    % Increase font size
    curFont = pane.getFont();
    curFont = curFont.deriveFont(14);
    pane.setFont(curFont);
  end

  %------------------------------------------------------------------------
  function updateParamsClass()
    optionsStruct = fixFields(optionsStruct);
    if(isempty(optionsStruct))
      return;
    end
    optionsObject = optionsObject.set(optionsStruct);

    if(~isempty(parent))
      setappdata(gui, 'curClassParams', optionsObject);
    else
      setappdata(hFig, 'curClassParams', optionsObject);
    end
  end

  %------------------------------------------------------------------------
  function p = fixFields(p)
    if(isempty(p))
      return;
    end
    snames = fieldnames(p);
    for cit = 1:numel(snames)
      curField = snames{cit};
      newVal = p.(curField);
      if(isstruct(newVal))
        newVal = fixFields(newVal);
      else
        if(strcmp(curField, 'colormap'))
          cmapNames = p.(curField);
          mapNamePositions = strfind(cmapNames, 'png">');
          if(~isempty(mapNamePositions))
            newVal = cmapNames(mapNamePositions+5:end);
          end
        elseif(ischar(p.(curField)))
          strs = p.(curField);
          if(isempty(strs))
            newVal = [];
          elseif(strs(1) == '[' && strs(end) == ']')
            % It has to be eval'd
            try
              newVal = eval(p.(curField));
            catch
              newVal = [];
            end
          end
        end
      end
      p.(curField) = newVal;
    end
  end

  % Property updated callback function
  %--------------------------------------------------------------------------
  function propUpdatedCallback(prop, eventData, propName, fileData)
    try 
      if(strcmpi(char(eventData.getPropertyName),'parent'))
        return;
      end
    catch
    end

    % Retrieve the containing figure handle
    hFigb = get(0,'CurrentFigure'); %gcf;
    if(isempty(hFigb))
      hPropsPane = findall(0,'Tag','hpropertiesGUI');
      if isempty(hPropsPane)
        return;
      end
      hFigb = ancestor(hPropsPane,'figure'); %=get(hPropsPane,'Parent');
    end
    if(isempty(hFigb))
      return
    end

    % Get the props data from the figure's ApplicationData
    propsListb = getappdata(hFigb, 'propsList');
    propsPane = getappdata(hFigb, 'jPropsPane');

    % Bail out if arriving from tableDataUpdatedCallback
    try
      s = dbstack;
      if strcmpi(s(2).name, 'tableDataUpdatedCallback')
        return;
      end
    catch
      % ignore
    end

    % Get the updated property value
    propValue = get(prop,'Value');
    if isjava(propValue)
      if isa(propValue,'java.awt.Color')
        propValue = propValue.getColorComponents([])';  %#ok<NASGU>
      else
        propValue = char(propValue);  %#ok<NASGU>
      end
    end

    % Get the actual recursive propName
    propName = getRecursivePropName(prop, propName);

    % Find if the original item was a cell array and the mirror accordingly
    items = strread(propName,'%s','delimiter','.');
    if ~isempty(optionsStruct)
      cpy = optionsStruct;
      for idx = 1 : length(items)
        % This is for dealing with structs with multiple levels...
        [flag, index] = CheckStringForBrackets(items{idx});
        if flag
          cpy = cpy(index);
        else
          if isfield(cpy,items{idx})
            cpy = cpy.(items{idx});
          else
            return
          end
        end
      end
      if nargin == 4
        if iscell(cpy) && iscell(fileData) %%&& length(fileData)==1 % if mirror and filedata are cells then update the data -> otherwise overright.
          propValue=UpdateCellArray(cpy,fileData);
        end
      else
        if iscell(cpy)
          propValue = UpdateCellArray(cpy, propValue);
        end
      end
    end

    % Check for loading from file and long string which has been truncated
    if nargin == 4
      propValue = checkCharFieldForAbreviation(propValue,fileData);
      if ~isempty(propValue) && strcmp(propValue(1),'[') && ~isempty(strfind(propValue,' struct array]'))
        propValue = fileData;
      end
      if isempty(propValue) % a struct
        propValue = fileData;
      end
    end

    % For items with .(N) in the struct -> remove from path for eval
    propName = regexprep(propName,'\.(','(');

    % Update the mirror with the updated field value
    %data.(propName) = propValue;  % croaks on multiple sub-fields
    eval(['optionsStruct.' propName ' = propValue;']);

    % Update the local mirror
    updateParamsClass();

    % Update the display
    %checkProps(propsListb, hFigb);
    try
      propsPane.repaint;
    catch
    end
  end  % propUpdatedCallback

  %--------------------------------------------------------------------------
  function selectedValue = UpdateCellArray(originalData,selectedValue)
    if length(originalData)==length(selectedValue) || ~iscell(selectedValue)
      index=find(strcmp(originalData,selectedValue)==1);
      if iscell(originalData{end})
        originalData{end}={index};
      else
        if index~=1 % If it's not first index then we can save it
          originalData{end+1} = {index};
        end
      end
      selectedValue=originalData;
    else
      selectedValue=originalData;
    end
  end  % UpdateCellArray

  % Prepare a list of properties
  %--------------------------------------------------------------------------
  function [propsList, parameters] = preparePropsList(parameters, parametersDescriptions, isEditable)
    propsList = java.util.ArrayList();

    % Convert a class object into a struct
    if isobject(parameters)
      parameters = struct(parameters);
    end

    % Prepare a dynamic list of properties, based on the struct fields
    if isstruct(parameters) && ~isempty(parameters)
      allParameters = reshape(parameters, size(parameters,1),size(parameters,2),[]);
      numParameters = numel(allParameters);
      if numParameters > 1
        for zIdx = 1 : size(allParameters,3)
          for colIdx = 1 : size(allParameters,2)
            for rowIdx = 1 : size(allParameters,1)
              parameters = allParameters(rowIdx,colIdx,zIdx);
              field_name = '';
              field_label = sprintf('(%d,%d,%d)',rowIdx,colIdx,zIdx);
              field_label = regexprep(field_label,',1\)',')');  % remove 3D if unnecesary
              newProp = newProperty(parameters, field_name, field_label, isEditable, '', '', @propUpdatedCallback);
              propsList.add(newProp);
            end
          end
        end
      else
        % Dynamically (generically) inspect all the fields and assign corresponding props
        field_names = fieldnames(parameters);
        %parameters
        for field_idx = 1 : length(field_names)
          arrayData = [];
          field_name = field_names{field_idx};
          value = parameters.(field_name);
          field_label = getFieldLabel(field_name);
          if(~isempty(parametersDescriptions))
            try
              field_description = parametersDescriptions{field_idx};
            catch
              field_description = 'Help description could not be retrieved';
            end
          else
            field_description = '';
          end

          type = 'string';
          if(isempty(value))
            type = 'string';  % not really needed, but for consistency
          elseif(isa(value,'java.awt.Color'))
            type = 'color';
          elseif(isa(value,'java.awt.Font'))
            type = 'font';
          elseif(strcmpi(field_label, 'colormap'))
            type = 'colormap';
          elseif(isnumeric(value))
            if(numel(value) == 1)
              if(isa(value,'uint') || isa(value,'uint8') || isa(value,'uint16') || isa(value,'uint32') || isa(value,'uint64'))
                type = 'unsigned';
              elseif(isinteger(value))
                type = 'signed';
              else
                type = 'float';
              end
            else % a vector or a matrix
              value = num2str(value);
              if(size(value,1) > size(value,2))
                value = value';
              end
              if size(squeeze(value),2) > 1
                % Convert multi-row string into a single-row string
                value = [value'; repmat(' ',1,size(value,1))];
                value = value(:)';
              end
                value = strtrim(regexprep(value,' +',' '));
                if length(value) > 50
                  value(51:end) = '';
                  value = [value '...']; %#ok<AGROW>
                end
                value = ['[' value ']']; %#ok<AGROW>
            end
          elseif islogical(value)
            if numel(value)==1
              % a single value
              type = 'boolean';
            else % an array of boolean values
              arrayData = value;
              value = regexprep(sprintf('%dx',size(value)),{'^(.)','x$'},{'<$1','> logical array'});
            end
          elseif ischar(value)
            [fpa, ~, fpc] = fileparts(value);
            if exist(value,'dir')
              type = 'folder';
              value = java.io.File(value);
            % Since the file might not exist yet
            elseif exist(value,'file') || ~isempty(fpc) || (~isempty(fpa) && exist(fpa, 'dir'))
              if(isempty(fpa))
                type = 'string';
                if(length(value) > 50)
                  value(51:end) = '';
                  value = [value '...']; %#ok<AGROW>
                end
              else
                type = 'file';
                value = java.io.File(value);
              end
            else
              type = 'string';
              if length(value) > 50
                value(51:end) = '';
                value = [value '...']; %#ok<AGROW>
              end
            end
          elseif iscell(value) && size(value,1) == 1
            type = value;  % editable if the last cell element is ''
            if size(value,1)==1 || size(value,2)==1
              % vector - treat as a drop-down (combo-box/popup) of values
              if ~iscellstr(value)
                type = value;
                for ii=1:length(value)
                  if isnumeric(value{ii})  % if item is numeric -> change to string for display.
                    type{ii} = num2str(value{ii});
                  else
                    type{ii} = value{ii};
                  end
                end
              end
            else  % Matrix - use table popup
              %value = ['{ ' strtrim(regexprep(evalc('disp(value)'),' +',' ')) ' }'];
              arrayData = value;
              value = regexprep(sprintf('%dx',size(value)),{'^(.)','x$'},{'<$1','> cell array'});
            end  
          elseif iscell(value) && size(value,2) == 1
            arrayData = value;
            value = regexprep(sprintf('%dx',size(value)),{'^(.)','x$'},{'<$1','> cell array'});
          elseif isa(value,'java.io.File')
            if value.isFile
              type = 'file';
            elseif value.isDirectory
              type = 'folder';
            else
              %type = 'folder';
              type = 'file';
            end
          elseif isobject(value)
            oldWarn = warning('off','MATLAB:structOnObject');
            value = struct(value);
            warning(oldWarn);
          elseif ~isstruct(value)
            value = strtrim(regexprep(evalc('disp(value)'),' +',' '));
          end
          parameters.(field_name) = value;  % possibly updated above

          newProp = newProperty(parameters, field_name, field_label, isEditable, type, field_description, @propUpdatedCallback);
          propsList.add(newProp);
          parameters.(field_name) = newProp.getValue();
          % Save the array as a new property of the object
          if ~isempty(arrayData)
            try
              set(newProp,'arrayData',arrayData)
            catch
              hp = schema.prop(handle(newProp),'arrayData','mxArray'); %#ok<NASGU>
              set(handle(newProp),'arrayData',arrayData)
            end
            newProp.setEditable(false);
          end
        end
      end
    end
  end

  % Prepare a data property
  %--------------------------------------------------------------------------
  function prop = newProperty(dataStruct, propName, label, isEditable, dataType, description, propUpdatedCallback)
    % Auto-generate the label from the property name, if the label was not specified
    if isempty(label)
    label = getFieldLabel(propName);
    end

    % Create a new property with the chosen label
    prop = javaObjectEDT(com.jidesoft.grid.DefaultProperty);  % UNDOCUMENTED internal MATLAB component
    prop.setName(label);
    prop.setExpanded(true);

    % Set the property to the current patient's data value
    try
        thisProp = dataStruct.(propName);
    catch
        thisProp = dataStruct;
    end
    origProp = thisProp;

    if isstruct(thisProp)
      % Accept any object having data fields/properties
      try
        thisProp = get(thisProp);
      catch
        oldWarn = warning('off','MATLAB:structOnObject');
        thisProp = struct(thisProp);
        warning(oldWarn);
      end

      % Parse the children props and add them to this property
      if numel(thisProp) < 2
        prop.setValue('');
      else
        sz = size(thisProp);
        szStr = regexprep(num2str(sz),' +','x');
        prop.setValue(['[' szStr ' struct array]']);
      end
      prop.setEditable(false);
      % Here is where we should try to get the descriptions somehow
      % Let's prase the description and trim it
      d = strtrim(strsplit(description, '\n'));
      fields = fieldnames(thisProp);
      % First pass to get the first index list
      validIdxList = [];
      for itt = 1:length(fields)
        validIdx = find(strcmpi(d, [fields{itt} ':']));
        validIdxList = [validIdxList; validIdx]; %#ok<AGROW>
      end
      % Add empty lines and the last line
      validLastIdx2 = find(cellfun(@(x)isempty(x), d));
      validLast = unique([validIdxList(:); validLastIdx2(:); length(d)+1]);
      newDesc = cell(length(fields), 1);
      for itt = 1:length(fields)
        validIdx = find(strcmpi(d, [fields{itt} ':']));
        % Now find the last index
        if(isempty(validIdx))
          continue;
        end
        validIdxLast = validLast(find(validLast > validIdx, 1, 'first')); % Find next termination index
        listset = (validIdx+1):(validIdxLast-1);
        newDesc{itt} = strjoin(d(listset),'\n');
      end

      [children, ~] = preparePropsList(thisProp, newDesc, isEditable);
      children = toArray(children);
      for childIdx = 1:length(children)
        prop.addChild(children(childIdx));
      end
    else
      prop.setValue(thisProp);
      prop.setEditable(isEditable);
    end

    % Set property editor, renderer and alignment
    if iscell(dataType)
      % treat this as drop-down values
      % Set the defaults
      firstIndex = 1;
      cbIsEditable = false;
      % Extract out the number of items in the user list
      nItems = length(dataType);
      % Check for any empty items
      emptyItem = find(cellfun('isempty', dataType) == 1);
      % If only 1 empty item found check editable rules
      if length(emptyItem) == 1
        % If at the end - then remove it and set editable flag
        if emptyItem == nItems
          cbIsEditable = true;
          dataType(end) = []; % remove from the drop-down list
        elseif emptyItem == nItems - 1
          cbIsEditable = true;
          dataType(end-1) = []; % remove from the drop-down list
        end
      end

      % Try to find the initial (default) drop-down index
      if ~isempty(dataType)
        if iscell(dataType{end})
          if isnumeric(dataType{end}{1})
            firstIndex = dataType{end}{1};
            dataType(end) = []; % remove the [] from drop-down list
          end
        else
          try
            if ismember(dataType{end}, dataType(1:end-1))
              firstIndex = find(strcmp(dataType(1:end-1),dataType{end}));
              dataType(end) = [];
            end
          catch % #ok<NOCOM>
          end
        end

        % Build the editor
        %editor = com.jidesoft.grid.ListComboBoxCellEditor(dataType);
        editor = com.jidesoft.grid.LegacyListComboBoxCellEditor(dataType);
        try editor.getComboBox.setEditable(cbIsEditable); catch, end % #ok<NOCOM>
        alignProp(prop, editor);

        try
          prop.setValue(origProp{firstIndex});
        catch
        end
      end
    elseif(strcmp(dataType,'colormap'))
      cbIsEditable = false;
      htmlStrings = getHtmlColormapNames({'parula', 'morgenstemning', 'jet', 'isolum', 'lines'}, 100, 15);

      colormapList = htmlStrings;
      editor = com.jidesoft.grid.LegacyListComboBoxCellEditor(colormapList);
      try
        editor.getComboBox.setEditable(cbIsEditable);
      catch
      end % #ok<NOCOM>
      alignProp(prop, editor);
      try prop.setValue(colormapList{1}); catch, end
    else
      switch lower(dataType)
        case 'signed'    %alignProp(prop, com.jidesoft.grid.IntegerCellEditor,    'int32');
          modelb = javax.swing.SpinnerNumberModel(prop.getValue, -intmax, intmax, 1);
          editor = com.jidesoft.grid.SpinnerCellEditor(modelb);
          alignProp(prop, editor, 'int32');
        case 'unsigned'  %alignProp(prop, com.jidesoft.grid.IntegerCellEditor,    'uint32');
          val = max(0, min(prop.getValue, intmax));
          modelb = javax.swing.SpinnerNumberModel(val, 0, intmax, 1);
          editor = com.jidesoft.grid.SpinnerCellEditor(modelb);
          alignProp(prop, editor, 'uint32');
        case 'float'     %alignProp(prop, com.jidesoft.grid.CalculatorCellEditor, 'double');  % DoubleCellEditor
          alignProp(prop, com.jidesoft.grid.DoubleCellEditor, 'double');
        case 'boolean'
          alignProp(prop, com.jidesoft.grid.BooleanCheckBoxCellEditor, 'logical');
        case 'folder'
          alignProp(prop, com.jidesoft.grid.FolderCellEditor);
        case 'file'
          alignProp(prop, com.jidesoft.grid.FileCellEditor);
        case 'color'
          alignProp(prop, com.jidesoft.grid.LegacyColorCellEditor);
        case 'font'
          alignProp(prop, com.jidesoft.grid.FontCellEditor);
        case 'text'
          alignProp(prop);
        otherwise
          alignProp(prop);  % treat as a simple text field
      end
    end  % for all possible data types

    prop.setDescription(description);

    % Set the property's editability state
    if prop.isEditable
      % Set the property's label to be black
      prop.setDisplayName(['<html><font color="black">' label]);

      % Add callbacks for property-change events
      hprop = handle(prop, 'CallbackProperties');
      set(hprop,'PropertyChangeCallback',{propUpdatedCallback,propName});
    else
      % Set the property's label to be gray
      prop.setDisplayName(['<html><font color="gray">' label]);
    end
    setPropName(prop,propName);
  end


  % Return java.lang.Class instance corresponding to the Matlab type
  %------------------------------------------------------------------------
  function jclass = javaclass(mtype, ndims)
      % Input arguments:
      % mtype:
      %    the MatLab name of the type for which to return the java.lang.Class
      %    instance
      % ndims:
      %    the number of dimensions of the MatLab data type
      %
      % See also: class

      % Copyright 2009-2010 Levente Hunyadi
      % Downloaded from: http://www.UndocumentedMatlab.com/files/javaclass.m

      validateattributes(mtype, {'char'}, {'nonempty','row'});
      if nargin < 2
          ndims = 0;
      else
          validateattributes(ndims, {'numeric'}, {'nonnegative','integer','scalar'});
      end

      if ndims == 1 && strcmp(mtype, 'char');  % a character vector converts into a string
          jclassname = 'java.lang.String';
      elseif ndims > 0
          jclassname = javaarrayclass(mtype, ndims);
      else
          % The static property .class applied to a Java type returns a string in
          % MatLab rather than an instance of java.lang.Class. For this reason,
          % use a string and java.lang.Class.forName to instantiate a
          % java.lang.Class object; the syntax java.lang.Boolean.class will not do so
          switch mtype
              case 'logical'  % logical vaule (true or false)
                  jclassname = 'java.lang.Boolean';
              case 'char'  % a singe character
                  jclassname = 'java.lang.Character';
              case {'int8','uint8'}  % 8-bit signed and unsigned integer
                  jclassname = 'java.lang.Byte';
              case {'int16','uint16'}  % 16-bit signed and unsigned integer
                  jclassname = 'java.lang.Short';
              case {'int32','uint32'}  % 32-bit signed and unsigned integer
                  jclassname = 'java.lang.Integer';
              case {'int64','uint64'}  % 64-bit signed and unsigned integer
                  jclassname = 'java.lang.Long';
              case 'single'  % single-precision floating-point number
                  jclassname = 'java.lang.Float';
              case 'double'  % double-precision floating-point number
                  jclassname = 'java.lang.Double';
              case 'cellstr'  % a single cell or a character array
                  jclassname = 'java.lang.String';
              otherwise
                  jclassname = mtype;
                  %error('java:javaclass:InvalidArgumentValue', ...
                  %    'MatLab type "%s" is not recognized or supported in Java.', mtype);
          end
      end
      % Note: When querying a java.lang.Class object by name with the method
      % jclass = java.lang.Class.forName(jclassname);
      % MatLab generates an error. For the Class.forName method to work, MatLab
      % requires class loader to be specified explicitly.
      jclass = java.lang.Class.forName(jclassname, true, java.lang.Thread.currentThread().getContextClassLoader());
  end  % javaclass

  % Align a text property to right/left
  %------------------------------------------------------------------------
  function alignProp(prop, editor, propTypeStr, direction)

      persistent propTypeCache
      if isempty(propTypeCache),  propTypeCache = java.util.Hashtable;  end

      if nargin < 2 || isempty(editor),      editor = com.jidesoft.grid.StringCellEditor;  end  %(javaclass('char',1));
      if nargin < 3 || isempty(propTypeStr), propTypeStr = 'cellstr';  end  % => javaclass('char',1)
      if nargin < 4 || isempty(direction),   direction = javax.swing.SwingConstants.RIGHT;  end
      % I'd rather just align everything to the left
      direction = javax.swing.SwingConstants.LEFT;
      % Set this property's data type
      propType = propTypeCache.get(propTypeStr);
      if isempty(propType)
          propType = javaclass(propTypeStr);
          propTypeCache.put(propTypeStr,propType);
      end
      prop.setType(propType);

      % Prepare a specific context object for this property
      if strcmpi(propTypeStr,'logical')
          %TODO - FIXME
          context = editor.CONTEXT;
          prop.setEditorContext(context);

          renderer = com.jidesoft.grid.BooleanCheckBoxCellRenderer;
          renderer.setHorizontalAlignment(direction);
          com.jidesoft.grid.CellRendererManager.registerRenderer(propType, renderer, context);
      else
          context = com.jidesoft.grid.EditorContext(prop.getName);
          prop.setEditorContext(context);

          % Register a unique cell renderer so that each property can be modified seperately
          %renderer = com.jidesoft.grid.CellRendererManager.getRenderer(propType, prop.getEditorContext);
          renderer = com.jidesoft.grid.ContextSensitiveCellRenderer;
          com.jidesoft.grid.CellRendererManager.registerRenderer(propType, renderer, context);
          renderer.setBackground(java.awt.Color.white);
          renderer.setHorizontalAlignment(direction);
          %renderer.setHorizontalTextPosition(direction);
      end

      % Update the property's cell editor
      try editor.setHorizontalAlignment(direction); catch, end
      try editor.getTextField.setHorizontalAlignment(direction); catch, end
      try editor.getComboBox.setHorizontalAlignment(direction); catch, end

      % Set limits on unsigned int values
      try
          if strcmpi(propTypeStr,'uint32')
              %pause(0.01);
              editor.setMinInclusive(java.lang.Integer(0));
              editor.setMinExclusive(java.lang.Integer(-1));
              editor.setMaxExclusive(java.lang.Integer(intmax));
              editor.setMaxInclusive(java.lang.Integer(intmax));
          end
      catch
          % ignore
      end
      com.jidesoft.grid.CellEditorManager.registerEditor(propType, editor, context);
  end  % alignProp

  % Set property name in the Java property reference
  %------------------------------------------------------------------------
  function setPropName(hProp,propName)
    try
      set(hProp,'UserData',propName)
    catch
      hp = schema.prop(handle(hProp),'UserData','mxArray'); %#ok<NASGU>
      set(handle(hProp),'UserData',propName)
    end
  end

  % Get property name from the Java property reference
  %--------------------------------------------------------------------------
  function propName = getPropName(hProp)
    try
      propName = get(hProp,'UserData');
    catch
      propName = get(handle(hProp),'UserData');
    end
  end

  % Get a normalized field label (see also checkFieldName() below)
  %------------------------------------------------------------------------
  function field_label = getFieldLabel(field_name)
    field_label = regexprep(field_name, '__(.*)', ' ($1)');
    field_label = strrep(field_label,'_',' ');
    field_label(1) = upper(field_label(1));
  end

  % Get recursive property name
  %------------------------------------------------------------------------
  function propName = getRecursivePropName(prop, propBaseName)
    try
      oldWarn = warning('off','MATLAB:hg:JavaSetHGProperty');
      try prop = java(prop); catch, end
      if nargin < 2
        propName = getPropName(prop);
      else
        propName = propBaseName;
      end
      while isa(prop,'com.jidesoft.grid.Property')
        prop = get(prop,'Parent');
        newName = getPropName(prop);
        if isempty(newName)
          % check to see if it's a (1,1)
          displayName = char(prop.getName);
          [flag, index] = CheckStringForBrackets(displayName);
          if flag
            propName = sprintf('(%i).%s',index,propName); 
          else                
            break; 
          end
        else
          propName = [newName '.' propName]; %#ok<AGROW>
        end
      end
    catch
      % Reached the top of the property's heirarchy - bail out
      warning(oldWarn);
    end
  end

  %------------------------------------------------------------------------
  function [flag, index] = CheckStringForBrackets(str)
    index = [];
    flag = strcmp(str(1),'(') && strcmp(str(end),')');
    if flag
      index = max(str2num(regexprep(str,'[()]','')));  % this assumes it's always (1,N) or (N,1)
    end
  end
end