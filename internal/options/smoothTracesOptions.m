classdef smoothTracesOptions < baseOptions
% SMOOTHTRACESOPTIONS Smooth traces options
%   Class containing the possible ways in which to smooth the traces
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also smothTraces, baseOptions, optionsWindow

  properties
    % Type of traces to use, raw (standard)  or denoised
    tracesType = {'raw', 'denoised'};
    
    % Normalization procedure to apply to the data
    % - '100x(F-F0)/F0' - data is normalized as deviation percentage from mean fluorescence (F0)
    % - '(F-F0)/F0' - data is normalized as deviation unit from mean fluorescence (F0)
    % - 'none'
    dataNormalization = {'100x(F-F0)/F0', '(F-F0)/F0', 'none'};

    % Type of smoothing to apply:
    % - 'moving average' - smooth(signal, 5,'moving')
    % - 'backwards moving average' - like moving average, but only looking at past values (filter)
    % - 'median filter' - medfilt1(signal, 5)
    % - 'Savitzky-Golay' - smooth(signal, 12,'sgolay',3)
    % - 'local regression' - smooth(signal, 5, 'rlowess')
    % - 'peak enhancement' - mslowess(time, signal)
    % - 'none'
    smoothingMethod = {'moving average', 'median filter', 'backwards moving average', 'Savitzky-Golay', 'local regression', 'peak enhancement', 'none'};

    % Length in (s) of the smoothing window. Leave at 0 to use default values. Only applies to moving average, savitzky-Golay and local regression
    smoothingWindow = 0;

    % Type of fitting for baseline correction:
    % - 'spline fitting'
    % - 'spline fitting percentile correction' (requires avgTraceLower from preprocessExperiment)
    % - 'none'
    % - 'linear fit'
    % - 'fft' - detrends the signal and removes desired frequnecies - Please note that fft fitting might change fluorescence values
    % - Any positive integer - Corresponds to a polynomial fit of the specified order
    polyFitType = {'spline fitting', 'spline fitting percentile correction', 'none', 'linear fit', 'fft', ''};

    % Frequencies below the first value will be eliminated from the signals. Frequencies above the second value will be eliminated from the signals (keep in mind that the maximum resovable frequency is ~fps/2). In Hz
    fftFrequencies = [0.01 inf];
    
    % Length (in seconds) of each division for spline fitting (if polyFitType = spline fitting). The larger the number, the higher the accuracy in tracing the data (but also the higher the amount of features you lose) (positive double)
    splineDivisionLength = 25;

    % Only uses this fraction of values on each block to compute the mean of the block for the spline fitting (if polyFItType = 'spline fitting')
    splineDivisionFraction = 0.1;

    % Smoothing parameter for spline fitting. Leave at 0 for default. Between 0 and 1. Increase to make more strict spline fitting
    splineSmoothingParam = 0;
    
    % If true, will make sure that no kinks appear on the data (due to the new baseline going above the original data)
    splineKinkCorrection@logical = false;
    
    % Baseline correction:
    % - 'mean' - data will be centered around its mean
    % - 'block' - data will be shifted upwards so the baseline is at ~0 at each block (see blockSize)
    % - 'moving average' - will substract at each point the result of a moving average with a given blockLength (see blocKLength)
    % - 'none' - no baseline correction
    baseLineCorrection = {'block', 'mean', 'moving average', 'none'};

    % Length of blocks (in seconds) for baseLine correction (if baseLine = block or moving average) (positive integer)
    blockLength = 25;

    % Only uses this fraction of values on each block to compute the mean of the block for the baseline correction (if baseLine = 'block')
    blockDivisionFraction = 0.1;

    % If the computed baseline is also stored (only used for debugging purposes) (true/false)
    storeBaseline = false;
    
    % Decreate the initial fluorescence by this value (for every ROI and
    % time point)
    offsetParameter = 0;
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.splineDivisionLength = min([25 round(round(experiment.totalTime)/2)]);
          obj.blockLength = round(experiment.totalTime);
        catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'totalTime');
        if(isfield(exp, 'totalTime'))
          obj.splineDivisionLength = min([25 round(round(experiment.totalTime)/2)]);
          obj.blockLength = round(experiment.totalTime);
        end
      end
    end
  end
end
