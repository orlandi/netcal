function [selectionNames selectionStruct] = treeGroupsSelection(experiment, title, editable, selectable)
% TREEGROUPSSELECTION opens a tree window to select and modify groups
%
% USAGE:
%   selection = treeGroupsSelection(experiment)
%
% INPUT arguments:
%   experiment - experiment structure
%
% INPUT optional arguments: 
%   title - The window title. If missing it will use Select Groups
%
% OUTPUT arguments:
%   selection - selected groups - empty if nothing
%
% EXAMPLE:
%   selection = treeGroupsSelection(experiment, title)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

if(nargin < 2)
  title = 'Select Groups';
end
if(nargin < 3)
  editable = true;
end
if(nargin < 4)
  selectable = true;
end
selectionNames = [];
selectionStruct = [];

hFig = figure('CloseRequestFcn', @closeCallback,...
              'Resize','on',...
              'Toolbar', 'none',...
              'Tag','treeTest', ...
              'DockControls','off',...
              'NumberTitle', 'off',...
              'Pos',[300,200,400,500],...
              'MenuBar', 'none',...
              'Name', title, ...
              'Visible', 'off');

import uiextras.jTree.*;



set(hFig, 'WindowStyle','modal');
hs.mainWindowGrid = uix.VBox('Parent', hFig);
hs.mainWindowFramesPanel = uix.Panel('Parent', hs.mainWindowGrid, 'Padding', 5, 'BorderType', 'none');
if(selectable)
  treeObject = uiextras.jTree.CheckboxTree('Parent', hs.mainWindowFramesPanel, 'RootVisible', false);
else
  treeObject = uiextras.jTree.Tree('Parent', hs.mainWindowFramesPanel, 'RootVisible', false);
end

hs.mainWindowBottomButtons = uix.HBox( 'Parent', hs.mainWindowGrid);
% Add the bottom action buttons
btOK     = uicontrol('Parent', hs.mainWindowBottomButtons, 'String','OK', 'Tag','btOK',     'Callback',@btOK_Callback); %#ok<NASGU>
btCancel = uicontrol('Parent', hs.mainWindowBottomButtons, 'String','Cancel', 'Tag','btCancel', 'Callback',@(h,e)close(hFig)); %#ok<NASGU>
uix.Empty('Parent', hs.mainWindowBottomButtons);
set(hs.mainWindowBottomButtons, 'Widths', [100 100 -1], 'Padding', 5, 'Spacing', 5);
set(hs.mainWindowGrid, 'Heights', [-1 50]);

Icon1 = fullfile(matlabroot,'toolbox','matlab','icons','foldericon.gif');
groups = experiment.traceGroupsNames;
groupNames = fieldnames(groups);

% Drop everything
for i = 1:length(groupNames)
  if(strcmpi(groupNames{i}, 'everything'))
    continue;
  end
  groupNode = uiextras.jTree.CheckboxTreeNode('Name', groupNames{i}, 'TooltipString', groupNames{i}, 'Parent',treeObject.Root);
  if(editable)
    cmenu = uicontextmenu('Parent', hFig);
    uimenu(cmenu,'Label','Rename', 'Callback', {@renameMethod, groupNode});
    set(groupNode,'UIContextMenu',cmenu)
  end
  setIcon(groupNode, Icon1);
  groupMembers = groups.(groupNames{i});
  for j = 1:length(groupMembers)
    groupMemberNode = uiextras.jTree.CheckboxTreeNode('Name', groupMembers{j}, 'TooltipString', groupMembers{j}, 'Parent', groupNode);
    if(editable)
      cmenu = uicontextmenu('Parent', hFig);
      uimenu(cmenu,'Label','Rename', 'Callback', {@renameMethod, groupMemberNode});
      set(groupMemberNode, 'UIContextMenu', cmenu)
    end
  end
end
if(editable)
  treeObject.Editable = true;
end
hFig.Visible = 'on';

waitfor(hFig);

%--------------------------------------------------------------------------
function renameMethod(hObject, eventData, handle)
  answer = inputdlg('Enter new name',...
                    'Group rename', [1 60], {handle.Name});
  if(isempty(answer))
      return;
  else
    handle.Name = answer{1};
    % Dom smt else
  end
end

%--------------------------------------------------------------------------
function btOK_Callback(hObject, ~)
  selectionNames = {};
  selectionStruct = struct;
  orderNames = fieldnames(experiment.traceGroupsOrder);
  if(selectable)
    checkedList = treeObject.CheckedNodes;
  else
    checkedList = treeObject.Root.Children;
  end
  if(length(checkedList) == 1 && checkedList(1) == treeObject.Root)
    checkedList = checkedList(1).Children;
  end
  for i = 1:length(checkedList)
    curNode = checkedList(i);
    % If the parent is checked, get all children
    if(curNode.Parent == treeObject.Root)
      groupMembers = curNode.Children;
      for j = 1:length(groupMembers)
        selectionNames{end+1} = [curNode.Name ':' groupMembers(j).Name];
        selectionStruct.traceGroups.(curNode.Name){j} = experiment.traceGroups.(curNode.TooltipString){j};
        selectionStruct.traceGroupsNames.(curNode.Name){j} = groupMembers(j).Name;
        for k = 1:length(orderNames)
          if(isfield(experiment.traceGroupsOrder.(orderNames{k}), curNode.TooltipString))
            selectionStruct.traceGroupsOrder.(orderNames{k}).(curNode.Name){j} = experiment.traceGroupsOrder.(orderNames{k}).(curNode.TooltipString){j};
          end
        end
      end
    else
      rootName = curNode.Parent.Name;
      selectionNames{end+1} = [rootName ': ' curNode.Name];
      groupMembers = curNode.Parent.Children;
      for j = 1:length(groupMembers)
        if(strcmpi(curNode.TooltipString, groupMembers(j).TooltipString))
          if(~isfield(selectionStruct, 'traceGroups'))
            selectionStruct.traceGroups = struct;
          end
          if(~isfield(selectionStruct, 'traceGroupsNames'))
            selectionStruct.traceGroupsNames = struct;
          end
          if(~isfield(selectionStruct, 'traceGroupsOrder'))
            selectionStruct.traceGroupsOrder = struct;
          end
          if(~isfield(selectionStruct.traceGroups, rootName))
            selectionStruct.traceGroups.(rootName) = {};
          end
          if(~isfield(selectionStruct.traceGroupsNames, rootName))
            selectionStruct.traceGroupsNames.(rootName) = {};
          end
          selectionStruct.traceGroups.(rootName){end+1} = experiment.traceGroups.(curNode.Parent.TooltipString){j};
          selectionStruct.traceGroupsNames.(rootName){end+1} = curNode.Name;          
          for k = 1:length(orderNames)
            if(~isfield(experiment.traceGroupsOrder.(orderNames{k}), curNode.Parent.TooltipString))
              continue;
            end
            if(~isfield(selectionStruct.traceGroupsOrder, orderNames{k}))
              selectionStruct.traceGroupsOrder.(orderNames{k}) = struct;
            end
            if(~isfield(selectionStruct.traceGroupsOrder.(orderNames{k}), rootName))
              selectionStruct.traceGroupsOrder.(orderNames{k}).(rootName) = {};
            end
            selectionStruct.traceGroupsOrder.(orderNames{k}).(rootName){end+1} = experiment.traceGroupsOrder.(orderNames{k}).(curNode.Parent.TooltipString){j};
          end
        end
      end
    end
  end
  % Just in case
  if(isempty(selectionNames))
    selectionNames = [];
  end
  delete(hFig);
end

%--------------------------------------------------------------------------
function closeCallback(hObject, ~, ~)
  delete(hObject);
end

end
