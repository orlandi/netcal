classdef customTreeDnD < uiextras.jTree.Tree
% customTreeDnD Pending
% Heavily based on the uiextras.jTree
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>

  properties
    fileDropEnabled;
  end
  %% Constructor
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   methods
     function t = customTreeDnD(varargin)
       t@uiextras.jTree.Tree(varargin{:});
       t.fileDropEnabled = false;
     end
   
    function processFiles(tObj, files)
        files
    end
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
          treePath = tObj.jTree.getPathForLocation(...
              Loc.getX, Loc.getY);
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

          if(TargetOk && all(arrayfun(@(x) isa(x.Tree, 'TreeFunctionList'), SourceNode)))
            if(isa(TargetNode.Tree, 'TreeFunctionList'))
              dragType = 'none';
            elseif(isa(TargetNode.Tree, 'CheckboxTreePipeline'))
              dragType = 'functionToPipeline';
            end
          elseif(TargetOk && all(arrayfun(@(x) isa(x.Tree, 'CheckboxTreePipeline'), SourceNode)))
            if(isa(TargetNode.Tree, 'TreeFunctionList'))
              dragType = 'delete';
            elseif(isa(TargetNode.Tree, 'CheckboxTreePipeline'))
              dragType = 'move';
            end
          end
          TargetOk = TargetOk && ~strcmpi(dragType, 'none');
          
         
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
                  tObj.processFiles(files);
                end
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
                      case 'copy'
                        NewSourceNode = copy(SourceNode,TargetNode);
                        idList = arrayfun(@(x)max(x.UserData{1}), TargetNode.Children, 'UniformOutput', false);
                        maxID = max(cell2mat(idList));
                        if(isempty(maxID))
                          maxID = 0;
                        end
                        NewSourceNode.UserData{1} = maxID + 1;
                        % Need to redo the names
                        childrenList = TargetNode.Children;
                        for i = 1:length(childrenList)
                          childrenList(i).Name = sprintf('%3.d. %s', i, childrenList(i).TooltipString);
                          if(length(childrenList(i).UserData) > 5 && ~isempty(childrenList(i).UserData{6}))
                            colName = selectNodeColor(childrenList(i));
                            childrenList(i).Name = strrep(childrenList(i).Name, ' ', '&nbsp;');
                            childrenList(i).Name = sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(childrenList(i).Name, '<[^>]*>', ''));
                          end
                        end
                        expand(TargetNode);
                        expand(SourceNode);
                        expand(NewSourceNode);
                      case 'move'
                        if(isempty(targetNodeOriginal))
                          set(SourceNode,'Parent',TargetNode)
                          % Rename all nodes
                          childrenList = TargetNode.Children;
                          for i = 1:length(childrenList)
                            childrenList(i).Name = sprintf('%3.d. %s', i, childrenList(i).TooltipString);
                            if(length(childrenList(i).UserData) > 5 && ~isempty(childrenList(i).UserData{6}))
                              colName = selectNodeColor(childrenList(i));
                              childrenList(i).Name = strrep(childrenList(i).Name, ' ', '&nbsp;');
                              childrenList(i).Name = sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(childrenList(i).Name, '<[^>]*>', ''));
                            end
                          end
                        else
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
                            if(length(childrenList(i).UserData) > 5 && ~isempty(childrenList(i).UserData{6}))
                              colName = selectNodeColor(childrenList(i));
                              childrenList(i).Name = strrep(childrenList(i).Name, ' ', '&nbsp;');
                              childrenList(i).Name = sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(childrenList(i).Name, '<[^>]*>', ''));
                            end
                          end
                          % Keep the tree invisible
                          TargetNode.Tree.Visible = 'off';
                          set(childrenList, 'Parent', TargetNode);
                          TargetNode.Tree.Visible = 'on';
                        end
                        %return;
                        expand(TargetNode)
                        expand(SourceNode)
                    end
                  case 'delete'
                    SourceNodeRoot = SourceNode.Parent;
                    delete(SourceNode);
                    % Rename all nodes
                    childrenList = SourceNodeRoot.Children;
                    for i = 1:length(childrenList)
                      childrenList(i).Name = sprintf('%3.d. %s', i, childrenList(i).TooltipString);
                      if(length(childrenList(i).UserData) > 5 && ~isempty(childrenList(i).UserData{6}))
                        colName = selectNodeColor(childrenList(i));
                        childrenList(i).Name = strrep(childrenList(i).Name, ' ', '&nbsp;');
                        childrenList(i).Name = sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(childrenList(i).Name, '<[^>]*>', ''));
                      end
                    end
                    %SourceNodeRoot.Tree.SelectedNodes
                    % Return the source of the deleted node
                    e1.Source = SourceNodeRoot;
                  % Each node should have a unique ID as UserData
                  case 'functionToPipeline'
                    
                    %newNode = copy(SourceNode, TargetNode);
                    newNodeList = [];
                    for k = 1:length(SourceNode)
                      if(isempty(SourceNode(k).Children))
                        newNodeList = [newNodeList, SourceNode(k)];
                      else
                        childrenList = SourceNode(k).Children;
                        for l = 1:length(childrenList)
                          newNodeList = [newNodeList, childrenList(l)];
                        end
                      end
                    end
                    for l = 1:length(newNodeList)
                      SourceNode = newNodeList(l);
                      newNode = uiextras.jTree.CheckboxTreeNode('Parent', TargetNode, 'Name', SourceNode.Name, 'UserData', SourceNode.UserData, 'TooltipString', SourceNode.TooltipString);
                      % Assign userdata - unique identifier
                      idList = arrayfun(@(x)max(x.UserData{1}), TargetNode.Children, 'UniformOutput', false);
                      maxID = max(cell2mat(idList));
                      if(isempty(maxID))
                        maxID = 0;
                      end
                      for k = 1:length(newNode)
                        newNode(k).UserData{1} = maxID + k;
                        newNode(k).TooltipString = SourceNode.TooltipString;
                        %newNode(k).TooltipString = regexprep(newNode(k).Name, '<[^>]*>', '');
                        % Change the name so it shows its position
                        newNode(k).Name = sprintf('%3.d. %s', find(newNode(k) == TargetNode.Children), newNode(k).TooltipString);
                        colName = selectNodeColor(newNode(k));
                        newNode(k).Name = strrep(newNode(k).Name, ' ', '&nbsp;');
                        newNode(k).Name = sprintf('<html><font color="%s">%s</font></html>', colName, regexprep(newNode(k).Name, '<[^>]*>', ''));
        
                        TargetNode.Tree.UserData{newNode(k).UserData{1}} = newNode(k).UserData{1};
                      end
                    end
                    %newNode(k).UserData
                end
              end
            % Is there a custom NodeDraggedCallback to call?
            e1.dragType = dragType;
            if TargetOk && ~isempty(tObj.NodeDroppedCallback)
              TargetOk = hgfeval(tObj.NodeDroppedCallback,tObj,e1);
            end  
            % Tell Java the drop is complete
            e.dropComplete(true)
          end
      end %if callbacksEnabled(tObj)
      
      function colName = selectNodeColor(node)
        switch node.UserData{6}
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
      end
    end %function onNodeDND
  end %private methods
end
  