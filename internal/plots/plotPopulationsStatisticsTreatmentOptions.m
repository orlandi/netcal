classdef plotPopulationsStatisticsTreatmentOptions < plotStatisticsTreatmentOptions & baseOptions
% PLOTPOPULATIONSSTATISTICSTREATMENTOPTIONS # Plot Population Statistics for a treatment
%   Produces a boxplot for a given population statistic
%   It can show a single box for each experimetn and group, or merge them together into a joint statistic. Change the groupingOrder for that.
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also plotPopulationsStatisticsTreatment, plotStatisticsTreatmentOptions, baseOptions, optionsWindow

  methods 
    function obj = setExperimentDefaults(obj, experiment)
      obj.statistic = {'absolute count', 'relative count'};
      obj = setExperimentDefaults@plotStatisticsTreatmentOptions(obj, experiment);
    end
  end
end
