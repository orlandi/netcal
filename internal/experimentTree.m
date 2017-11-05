classdef experimentTree < uiextras.jTree.CheckboxTree
% EXPERIMENTTREE Pending
% Heavily based on the uiextras.jTree
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>


  %% Properties
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  properties
    fileDropEnabled;
  end
  
  %% Constructor
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods
    function t = experimentTree(varargin)
      t@uiextras.jTree.CheckboxTree(varargin{:});
      t.fileDropEnabled = false;
    end
  
    %function processFiles(tObj, files)
        %files
    %end

    function onNodeDND(tObj, e, s)
      % The Transferable object is available only during drag
      persistent Transferable

      if callbacksEnabled(tObj)
        
          try %#ok<TRYNC>
              % The Transferable object is available only during drag
              Transferable = e.getTransferable;
              javaObjectEDT(Transferable); % Put it on the EDT
          end

          % Catch errors if unsupported items are dragged onto the
          % tree
          try
              DataFlavors = Transferable.getTransferDataFlavors;
              TransferData = Transferable.getTransferData(DataFlavors(1));
          catch %#ok<CTCH>
              TransferData = [];
          end
          if(tObj.fileDropEnabled)
            isFile = false;
           try
             ar = DataFlavors(1).getMimeType();
             if(strfind(ar, 'application/x-java-file-list; class=java.util.List'))
               isFile = true;
             end
               catch
             isFile = false;
           end
           if(s.getDropType() == 2)
              isFile = true;
           end
          else
            isFile = false;
          end


          % Get the source node(s)
          SourceNode = uiextras.jTree.TreeNode.empty(0,1);
          for idx = 1:numel(TransferData)
              SourceNode(idx) = get(TransferData(idx),'TreeNode');
          end

          % Filter descendant source nodes. If dragged nodes are
          % descendants of other dragged nodes, they should be
          % excluded so the hierarchy is maintained.
          try
            idxRemove = isDescendant(SourceNode,SourceNode);
          catch
            return;
          end
          SourceNode(idxRemove) = [];

          % Get the target node
          Loc = e.getLocation();
%           treePath = tObj.jTree.getPathForLocation(...
%               Loc.getX + tObj.jScrollPane.getHorizontalScrollBar().getValue(), Loc.getY + tObj.jScrollPane.getVerticalScrollBar().getValue());
          treePath = tObj.jTree.getPathForLocation(Loc.getX, Loc.getY);
            
            %tObj.jScrollPane.getVerticalScrollBar().getValue()
          if isempty(treePath)
              % If no target node, the target is the background of
              % the tree. Assume the root is the intended target.
              TargetNode = tObj.Root;
          else
              TargetNode = get(treePath.getLastPathComponent,'TreeNode');
              % Target node is always root
              %TargetNode
              %TargetNode = TargetNode.Parent;
              %TargetNode
              %2
              %TargetNode = tObj.Root;
          end

          % Get the operation type
          switch e.getDropAction()
  %                     case 0
  %                         DropAction = 'link';
            case 1
              DropAction = 'copy';
            case 2
              DropAction = 'move';
            otherwise
              DropAction = 'move';
  %                         DropAction = '';
          end
          
          % Only allow move drops for now 
          %DropAction = 'move';

          % Create event data for user callback
          e1 = struct(...
              'Source',SourceNode,...
              'Target',TargetNode,...
              'DropAction',DropAction);
            
          % Check the drag type
          % Only allow copy from functionList to pipeline
         
          % Check if the source/target are valid
          % Check the node is not dropped onto itself
          % Check a node may not be dropped onto a descendant
          
          TargetOk = ~isempty(TargetNode) &&...
              ~isempty(SourceNode) && ...
              ~any(SourceNode==TargetNode) && ...
              ~any(isDescendant(SourceNode,TargetNode));
            if(isFile && ~isempty(TargetNode))
              TargetOk = true;
            end
          dragType = 'none';

          % In here we will only allow move to move - no delete or copy (better safe than sorry)
          if(TargetOk && all(arrayfun(@(x) isa(x.Tree, 'experimentTree'), SourceNode)))
            if(isa(TargetNode.Tree, 'experimentTree'))
              dragType = 'move';
            end
          end

          TargetOk = TargetOk && ~strcmpi(dragType, 'none');
          if(isFile && ~isempty(TargetNode))
              TargetOk = true;
            end
         
          % A move operation may not drop a node onto its parent
          % Yes it can
          %if TargetOk && strcmp(DropAction,'move')
          %    TargetOk = ~any([SourceNode.Parent]==TargetNode);
          %end

          % Is this the drag or the drop event?
          if e.isa('java.awt.dnd.DropTargetDragEvent')
              %%%%%%%%%%%%%%%%%%%
              % Drag Event
              %%%%%%%%%%%%%%%%%%%

              % Is there a custom NodeDraggedCallback to call?
              if TargetOk && ~isempty(tObj.NodeDraggedCallback)
                  TargetOk = hgfeval(tObj.NodeDraggedCallback,tObj,e1);
              end

              % Is this a valid target?
              if TargetOk
                  e.acceptDrag(e.getDropAction);
              else
                  e.rejectDrag();
              end

          elseif e.isa('java.awt.dnd.DropTargetDropEvent')
              % Should we process the drop?

              if(isFile)
                if(s.getDropType() == 2)
                  % Here we do something with the file
                  files = cell(s.getTransferData());
                  %tObj.processFiles(files);
                  e1.files = cell(s.getTransferData());
                end
              if TargetOk && ~isempty(tObj.NodeDroppedCallback)
                e1.isFile = true;
                e1.dragType = dragType;
                e1.DropAction = DropAction;
                TargetOk = hgfeval(tObj.NodeDroppedCallback,tObj,e1);
              end  
              % Tell Java the drop is complete
              e.dropComplete(true)
              return;
              end
              if TargetOk
                if(~isempty(TargetNode.Parent))
                  % Find the new position
                  targetNodeOriginal = TargetNode;
                  TargetNode = TargetNode.Parent;
                else
                  targetNodeOriginal = [];
                end
                % Only allow copy from functionList to pipeline
                switch dragType
                  case 'move'
                    switch DropAction
                      case 'move'
                        if(isempty(targetNodeOriginal))
                          set(SourceNode,'Parent',TargetNode)
                          % Rename all nodes
                          childrenList = TargetNode.Children;
                          for i = 1:length(childrenList)
                            childrenList(i).Name = sprintf('%3.d. %s', i, childrenList(i).TooltipString);
                          end
                        else
                          prevSelection = TargetNode.Tree.SelectedNodes;
                          childrenList = TargetNode.Children;
                          % Look for the correct children
                          targetPos = [];
                          for i = 1:length(childrenList)
                            % Found it
                            if(childrenList(i) == targetNodeOriginal)
                              targetPos = i;
                              break;
                            end
                          end
                          % If something went wrong
                          if(isempty(targetPos))
                            return;
                          end
                          % targetPos is the children we selected
                          % We already know its the same tree, since we are just moving
                          % Lets store old positions
                          oldPos = zeros(length(SourceNode), 1);
                          for k = 1:length(SourceNode)
                            for j = 1:length(childrenList)
                              if(childrenList(j) == SourceNode(k))
                                oldPos(k) = j;
                                break;
                              end
                            end
                          end
                          % Now we have the list of old node positions
                          childrenList(oldPos) = [];
                          childrenList = [childrenList(1:targetPos-1), SourceNode, childrenList(targetPos:end)];
                          % Update their names
                          for i = 1:length(childrenList)
                            childrenList(i).Name = sprintf('%3.d. %s', i, childrenList(i).TooltipString);
                          end
                          % Keep the tree invisible
                          
                          TargetNode.Tree.Visible = 'off';
                          set(childrenList, 'Parent', TargetNode);
                          prevSelectionNames = arrayfun(@(x)x.UserData{1}, prevSelection, 'UniformOutput', false);
                          allNames = arrayfun(@(x)x.UserData{1}, childrenList, 'UniformOutput', false);
                          try
                            newList = cellfun(@(x)find(strcmp(x, allNames)), prevSelectionNames);
                          catch
                          end
                          TargetNode.Tree.SelectedNodes = childrenList(newList);
                          TargetNode.Tree.Visible = 'on';
                        end
                        %return;
                        expand(TargetNode)
                        expand(SourceNode)
                    end
                end
              end
            % Is there a custom NodeDraggedCallback to call?
            e1.dragType = dragType;
            if TargetOk && ~isempty(tObj.NodeDroppedCallback)
              e1.isFile = false;
              e1.dragType = dragType;
              e1.DropAction = DropAction;
              TargetOk = hgfeval(tObj.NodeDroppedCallback,tObj,e1);
            end  
            % Tell Java the drop is complete
            e.dropComplete(true)
          end
      end %if callbacksEnabled(tObj)
    end %function onNodeDND
  end %private methods
end %classdef
