classdef aggregatedOptions < baseOptions
% Optional input parameters for aggregatedOptions
%
% See also viewTraces

  properties
    % Distribution plot type (violin, boxplot, notboxplot, univarscatter)
    distributionType = {'violin', 'boxplot', 'notboxplot', 'univarscatter'};

    % Numbers to use when displaying count (relative to the total, or absolute values)
    countType = {'relative', 'absolute'}

    % If true, show numbers above bars (duh)
    showNumbersAboveBars = true;

    % Degrees of rotation for the x labels (0 horizontal, 90 vertical)
    xLabelsRotation = 0;

    % Main colormap
     colormap = 'parula';
  end
end