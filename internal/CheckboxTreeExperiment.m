classdef CheckboxTreeExperiment < uiextras.jTree.CheckboxTree
    % CheckboxTreeExperiment - Class definition for CheckboxTreeExperiment
    %   The CheckboxTree object places a checkbox tree control within a
    %   figure or container.
    %
    % Syntax:

  %% Properties
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% Constructor
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  methods
    function t = CheckboxTreeExperiment(varargin)
      t@uiextras.jTree.CheckboxTree(varargin{:});
      %t@customTreeDnD(varargin{:});
    end
  end

  %% Public Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Methods are functions that implement the operations performed on
  % objects of a class. They may be stored within the classdef file or as
  % separate files in a @classname folder.

  %% Protected Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  
  %% Get and Set Methods
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Get and set methods customize the behavior that occurs when code gets
  % or sets a property value.

end %classdef
