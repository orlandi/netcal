classdef baseOptions
% BASEOPTIONS Base NETCAL options class
%   Base class used to define user-changeable parameters for most NETCAL
%   GUI functions. Usually changed through an optionsWindow
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also baseOptions, optionsWindow

  properties
    % Enables the output of verbose information (true/false)
    verbose = true;
  end

  methods
    function equal = eq(obj1, obj2)
      % Checks if two set of options are equal (INCOMPLETE)
      equal = false;
      names1 = fieldnames(obj1);
      names2 = fieldnames(obj1);
      % Check that there are the same number of fields
      if(length(names1) ~= length(names2))
        return;
      else
        for i = 1:length(names1)
          % Check that all fields are the same
          if(~strcmpi(names1{i},names2{i}))
            return;
          end
          % Check that all fields contents are the same
          if(ischar(obj1.(names1{i})))
            if(any(~strcmpi(obj1.(names1{i}),obj2.(names1{i}))))
              return;
            end
          elseif(iscell(obj1.(names1{i})))
            cell1 = obj1.(names1{i});
            cell2 = obj1.(names1{i});
            for j = 1:length(cell1)
              if(cell1{j} ~= cell2{j})
                return;
              end
            end
          elseif(numel(obj1.(names1{i})) >1 )
            if(numel(obj1.(names1{i})) ~= numel(obj2.(names1{i})))
              return;
            end
            for j = 1:numel(obj1.(names1{i}))
              if(obj1.(names1{i})(j) ~= obj2.(names1{i})(j))
                return;
              end
            end
          else
            if(obj1.(names1{i}) ~= obj2.(names1{i}))
              return;
            end
          end
        end
      end
      equal = true;
    end

    function nequal = ne(obj1, obj2)
      % Checks if two set of options are different
      nequal = ~(obj1 == obj2);
    end

    function str = get(self)
      % Returns all properties as a structure - but not help
      str = struct;
      names = fieldnames(self);
      for i = 1:numel(names)
        if(~strcmpi(names{i}, 'help'))
          str.(names{i}) = self.(names{i});
        end
      end
    end

    function self = set(self, other)
      % Sets all properties from an structure or class with the
      % same field names
      %names = fieldnames(self);
      otherNames = fieldnames(other);
      for i = 1:numel(otherNames)
        if(isprop(self, otherNames{i}))
          self.(otherNames{i}) = other.(otherNames{i});
        end
      end
    end
    %function helpText = getHelp(self)
    %  helpText = self.help;
    %end
    function self = setDefaults(self)
      % For multioption dialogs will take the first value
      names = fieldnames(self);
      for i = 1:numel(names)
        if(isstruct(self.(names{i})))
          self.(names{i}) = setInnerValues(self.(names{i}));
        elseif(iscell(self.(names{i})) && size(self.(names{i}), 1) == 1 && size(self.(names{i}), 2) > 1)
          self.(names{i}) = self.(names{i}){1};
        end
      end
      function obj = setInnerValues(obj)
        namesb = fieldnames(obj);
        for j = 1:numel(namesb)
          if(isstruct(obj.(namesb{j})))
            obj.(namesb{j}) = setInnerValues(obj.(namesb{j}));
          elseif(iscell(obj.(namesb{j})) && size(obj.(namesb{j}), 1) == 1 && size(obj.(namesb{j}), 2) > 1)
            obj.(namesb{j}) = obj.(namesb{j}){1};
          end
        end
      end
    end
    function  self = setExperimentDefaults(self, ~)
    end
    function  self = setProjectDefaults(self, ~)
    end
  end
end
