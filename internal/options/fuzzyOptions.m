classdef fuzzyOptions < baseOptions
% FUZZYOPTIONS Options for the fuzzy classifier
%   Class containing the parameters to classify traces using a fuzzy classifier
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewTraces, baseOptions, optionsWindow

  properties
    % Number of groups to use for clasisfy (if the threshold is not 0 it will always add another group for the unclassified traces)
    numberGroups = 2;

    % Value and type of threshold to use.
    % - double: (between 0 and 1) the largest score above this threshold will be the neurons' group. Set it to 0 to just classify using the maximum score
    fuzzyThreshold = 0.7;
    
    % Type of features to use on the classification
    featureType = {'fluorescence', 'simplifiedPatterns', 'fullPatterns'};
  end
end
