classdef measureCrossCorrelationOptions < baseOptions
    properties
        %maxDivisions for determining maximum subdivisions (square)
        maxDivisions = [16]
        
        %Choose one of MatLab's built-in xCorr normalization options:
        % - none: no options
        % - biased: biased estimate
        % - unbiased: unbiased estimate
        % - coeff: autocorrelation at lag{0} = 1
        scaleopt = {'none', 'biased', 'unbiased', 'coeff'};
        
        %averaging for either total neurons (cells), spikes, or none
        % - none: no averaging
        % - cells: average for total number of neurons per division
        % - spikes: average for total spikes per division
        averaging = {'none', 'cells', 'spikes'};
      
    end
    
end
    
        