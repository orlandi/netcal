classdef reportOptions < baseOptions
% REPORTOPTIONS Options for the report class
%   Class containing the options to generate reports
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

    properties
    % filename of the report (without extension)
    reportFileName = 'report';

    % If true, show numbers above bars (duh)
    showNumbersAboveBars@logical = true;
    
    % Distribution plot type (violin, boxplot, notboxplot, univarscatter)
    distributionType = {'violin', 'boxplot', 'notboxplot', 'univarscatter'};
    
    % Degrees of rotation for the x labels (0 horizontal, 90 vertical)
    xLabelsRotation = 30;
        
    % Show slide with the ROI
    slideROI@logical = false;
    
    % Show slide with the raster-like fluorescence image (normalized)
    slideRasterNormalized@logical = false;
    
    % Show slide with the raster-like fluorescence image (non-normalized)
    slideRasterNonNormalized@logical = false;
    
    % Show slide with bursting statistics for neurons
    slideBurstNeurons@logical = false;
    
    % Show slide with bursting statistics for the first HCG
    slideBurstHCG@logical = false;
    
    % Show slide with event statistics for the glia population
    slideEventsGlia@logical = false;
    
    % Show slide with the aggregated information of the populations
    slideAggregatedPopulations@logical = true;
    
    % Show slide with the aggregated information of the bursts
    slideAggregatedBursts@logical = true;
    end
end
