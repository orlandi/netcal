classdef reportOptions < baseOptions
% REPORTOPTIONS Options for the report class
%   Class containing the options to generate reports
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also baseOptions, optionsWindow

    properties
    % filename of the report (without extension)
    reportFileName = 'report';

    % If true, show numbers above bars (duh)
    showNumbersAboveBars = true;
    
    % Distribution plot type (violin, boxplot, notboxplot, univarscatter)
    distributionType = {'violin', 'boxplot', 'notboxplot', 'univarscatter'};
    
    % Degrees of rotation for the x labels (0 horizontal, 90 vertical)
    xLabelsRotation = 30;
        
    % Show slide with the ROI
    slideROI = false;
    
    % Show slide with the raster-like fluorescence image (normalized)
    slideRasterNormalized = false;
    
    % Show slide with the raster-like fluorescence image (non-normalized)
    slideRasterNonNormalized = false;
    
    % Show slide with bursting statistics for neurons
    slideBurstNeurons = false;
    
    % Show slide with bursting statistics for the first HCG
    slideBurstHCG = false;
    
    % Show slide with event statistics for the glia population
    slideEventsGlia = false;
    
    % Show slide with the aggregated information of the populations
    slideAggregatedPopulations = true;
    
    % Show slide with the aggregated information of the bursts
    slideAggregatedBursts = true;
    end
end
