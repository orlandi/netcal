classdef smoothTracesV2Options < baseOptions
% SMOOTHTRACESV2OPTIONS Smooth traces options
%   Class containing the possible ways in which to smooth the traces
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also smothTraces, baseOptions, optionsWindow

  properties
    % Choose what movie to preprocess (standard or denoised)
    movieToPreprocess = {'standard', 'denoised'};
    
    % Normalization procedure to apply to the data
    % - '100x(F-F0)/F0' - data is normalized as deviation percentage from mean fluorescence (F0)
    % - '(F-F0)/F0' - data is normalized as deviation unit from mean fluorescence (F0)
    % - 'none'
    dataNormalization = {'100x(F-F0)/F0', '(F-F0)/F0', 'none'};


    % Length in (s) of the smoothing window. Leave at 0 to use default values. Only applies to moving average, savitzky-Golay and local regression
    smoothingWindow = 0;

    % Length (in seconds) of each division for spline fitting (if polyFitType = spline fitting). The larger the number, the higher the accuracy in tracing the data (but also the higher the amount of features you lose) (positive double)
    splineDivisionLength = 50;

    % Smoothing parameter for spline fitting. Leave at 0 for default. Between 0 and 1. Increase to make more strict spline fitting
    splineSmoothingParam = 1e-4;
    
    % If true, will make sure that no kinks appear on the data (due to the new baseline going above the original data)
    splineKinkCorrection@logical = true;
    
    % Baseline correction:
    % - 'mean' - data will be centered around its mean
    % - 'block' - like mean, but only computing the mean of the lowest block fraction of the signal (see blockdivisionfraction)
    % - 'none' - no baseline correction
    baseLineCorrection = {'block', 'mean', 'none'};

    % Only uses this fraction of values on each block to compute the mean of the block for the baseline correction (if baseLine = 'block')
    blockDivisionFraction = 0.1;
    
    % If the computed baseline is also stored (only used for debugging purposes) (true/false)
    storeBaseline = false;
    
    % True to only smooth a single trace and plot everything
    debug = false;
    
    % Trace to use for debugging
    debugTrace = 1;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.splineDivisionLength = min([25 round(round(experiment.totalTime)/2)]);
        catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
