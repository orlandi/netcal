classdef plotPermutationEntropyComplexityOptions < plotStatisticsOptions & baseOptions
% PLOTPERMUTATIONENTROPYCOMPLEXITYOPTIONS # Plot permutation complexity/entropy
%   Plots the permutation entropy or the permnutation complexity. See;
%   [http://dx.doi.org/10.1103/PhysRevE.95.062106](http://dx.doi.org/10.1103/PhysRevE.95.062106)
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotPermutationEntropyComplexity, plotBaseOptions, baseOptions, optionsWindow

  properties
    % Value of the fractional logarithm exponent (1 for the standard measure)
    qValue = 1;
  end
  
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'complexity', 'entropy'};
      obj = setExperimentDefaults@plotStatisticsOptions(obj, experiment);
    end
  end
end
