classdef viewTracesOptions < baseOptions
% VIEWTRACESOPTIONS View traces options
%   Class containing the view traces options
%
%   Copyright (C) 2016, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also viewTraces, baseOptions, optionsWindow

  properties
    % Number of traces to display per page
    numberTraces = 10;

    % Type of normalization to apply to the displayed traces:
    % - 'std' - Substract mean and divide by the standard deviation (default)
    % - 'std2x' - Substract mean and divide by 2 times the standard deviation
    % - 'mean' - Substract mean and divide by the mean
    % - 'global' - Normalize by the maximum and minimum fluorescence across all displayed traces
    % - 'global2x' - Normalize by the maximum and minimum fluorescence across all displayed traces and multiply by 2
    % - 'globalMax' - Normalize just by the maximum across all traces
    % - 'max' - Divide by the maximum across all displayed traces
    % - 'none' - Do not normalize
    % - 'fixedValue' - The number in normalizationMultiplier will be the new normalization maximum, e.g., 10 for showing 10DF/F as max
    % - any number - This will be the new normalization maximum, e.g., 10 for showing 10DF/F as max
    normalization = {'std', 'std2', 'mean', 'global', 'global2x', 'globalMax', 'max', 'none', 'fixedValue', ''};

    % Value to multiply each trace fluorescence values after
    % normalization. Set it to 0 for the default values:
    % - 'std' - 1/4
    % - 'std2x' - 1/8
    % - 'mean' - 1/10
    % - 'global' - 1
    % - 'global2x' - 2
    % - 'max' - 1
    % - 'none' - 1
    % Note that if you do not want the traces to overlap, the fluorescence values after normalization should be in the range (-0.5, 0.5)
    normalizationMultiplier = 0;
  end
end
