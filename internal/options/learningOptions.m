classdef learningOptions < baseOptions
% Optional input parameters for learningOptions
%
% See also viewTraces

  properties
    % Names for each of the groups
    groupNames = {'neuron';'glia';'noise'};

    % Type of classifier (for now just AdaBoostM2 and RobustBoost for 2 groups)
    trainer = {'AdaBoostM2', 'RobustBoost'};

    % Number of trees to generate for the classifier
    numberTrees = 200;
    
    % Type of features to use on the classification
    featureType = {'fluorescence', 'simplifiedPatterns', 'fullPatterns'};
  end
  methods
    function N = numberGroups(self)
    % Returns the number of groups
      N = length(self.groupNames);
    end
  end
end
