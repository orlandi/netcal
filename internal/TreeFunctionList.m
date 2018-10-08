classdef TreeFunctionList < uiextras.jTree.Tree & customTreeDnD
    % TreeFunctionList - Class definition for TreeFunctionList
    %   The CheckboxTree object places a checkbox tree control within a
    %   figure or container.
    %
    % Syntax:

  %% Properties
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% Constructor
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   methods
    function t = TreeFunctionList(varargin)
      t@uiextras.jTree.Tree(varargin{:});
      t@customTreeDnD(varargin{:});
    end
  end

  %% Public Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Methods are functions that implement the operations performed on
  % objects of a class. They may be stored within the classdef file or as
  % separate files in a @classname folder.

  %% Get and Set Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Get and set methods customize the behavior that occurs when code gets
  % or sets a property value.

end %classdef
