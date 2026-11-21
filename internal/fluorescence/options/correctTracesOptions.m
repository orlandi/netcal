classdef correctTracesOptions < baseOptions
% CORRECTTRACESOPTIONS Correct traces options
%   Class containing the possible ways in which to smooth the traces
%
%   Copyright (C) 2016-2025, Javier G. Orlandi <javier.orlandi@ucalgary.ca>
%
%   See also smothTraces, baseOptions, optionsWindow

  properties
    % Type of traces to use, raw (standard)  or denoised
    tracesType = {'raw', 'denoised'};
    
    % Decrease the original fluorescence by this value (for every ROI and
    % time point)
    offsetParameter = 0;
    
    % Options for data smoothing
    % method:
    % Type of smoothing to apply:
    % - 'moving average' - smooth(signal, 5,'moving')
    % - 'backwards moving average' - like moving average, but only looking at past values (filter)
    % - 'median filter' - medfilt1(signal, 5)
    % - 'Savitzky-Golay' - smooth(signal, 12,'sgolay',3)
    % - 'local regression' - smooth(signal, 5, 'rlowess')
    % - 'peak enhancement' - mslowess(time, signal)
    % - 'none'
    % window:
    % Length in (s) of the smoothing window. Leave at 0 to use default values. Only applies to moving average, savitzky-Golay and local regression
    smoothing = struct('method', {{'moving average', 'median filter', 'backwards moving average', 'Savitzky-Golay', 'local regression', 'peak enhancement', 'none'}}, ...
                       'window', 0);
    
    % Options for baseline correction
    % polyFitType:
    % Type of fitting for baseline correction:
    % - 'spline fitting'
    % - 'spline fitting percentile correction' (requires avgTraceLower from preprocessExperiment)
    % - 'none'
    % - 'linear fit'
    % - 'fft' - detrends the signal and removes desired frequnecies - Please note that fft fitting might change fluorescence values
    % - Any positive integer - Corresponds to a polynomial fit of the specified order
    % fftFrequencies:
    % Frequencies below the first value will be eliminated from the signals. Frequencies above the second value will be eliminated from the signals (keep in mind that the maximum resovable frequency is ~fps/2). In Hz
    % splineDivisionLength:
    % Length (in seconds) of each division for spline fitting (if polyFitType = spline fitting). The larger the number, the higher the accuracy in tracing the data (but also the higher the amount of features you lose) (positive double)
    % splineDivisionFraction:
    % Only uses this fraction of values on each block to compute the mean of the block for the spline fitting (if polyFItType = 'spline fitting')
    % splineSmoothingParam:
    % Smoothing parameter for spline fitting. Leave at 0 for default. Between 0 and 1. Increase to make more strict spline fitting
    % splineKinkCorrection:
    % If true, will make sure that no kinks appear on the data (due to the new baseline going above the original data)
    baseLineCorrection = struct('polyFitType', {{'spline fitting', 'spline fitting percentile correction', 'none', 'linear fit', 'fft', ''}}, ...
                                'fftFrequencies', [0.01 inf], ...
                                'splineDivisionLength', 25, ...
                                'splineDivisionFraction', 0.1, ...
                                'splineSmoothingParam', 0, ...
                                'splineKinkCorrection', false);

    % Options for neuropil correction (only for data from suite2p
    % active:
    % To whether the moving percentile is active
    % multiplier:
    % Multiplier for the neuropil correction: F = F-mult*Fneu
    neuropilCorrection = struct('active', false, ...
                                'multiplier', 0.7);

    % Options for movingPercentileCorrection correction
    % If active, this applies a moving percentile to estimate F0 insteead
    % of the previously estimated value
    % active:
    % To whether the moving percentile is active
    % percentileThreshold:
    % Percentile (in %) to use for F0 estimation
    % windowLength:
    % Size of the moving window (in seconds) - The window is causal (as it
    % will only use past information. If empty, the window size will be the
    % size of the recording (so a global substraction)
    movingPercentileCorrection = struct('active', false, ...
                                        'percentileThreshold', 15, ...
                                        'windowLength', 60);
    % Normalization procedure to apply to the data
    % - '100x(F-F0)/F0' - data is normalized as deviation percentage from mean fluorescence (F0)
    % - '(F-F0)/F0' - data is normalized as deviation unit from mean fluorescence (F0)
    % - '100x(F-F0)/F0' - data is normalized as deviation percentage from mean fluorescence (F0)
    % - '(F-F0)/F0' - data is normalized as deviation unit from mean fluorescence (F0)
    % - 'none'
    dataNormalization = {'100x(F-F0)/F0', '(F-F0)/F0', '100x(F-F0)/F0 fixed', '(F-F0)/F0 fixed', 'none'};
    
    % If the computed baseline is also stored (only used for debugging purposes) (true/false)
    storeBaseline = false;
  end
end
