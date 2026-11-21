classdef learningEventOptions < baseOptions
% Optional input parameters for learningOptions
%
% See also viewTraces

    properties
    % Names for each of the groups
    groupNames = {'neuron'; 'glia'};
    
    % Threshold to detect events (times the std deviation above the mean)
    eventLearningThreshold = 0.25;
    
    % Minimum length of an event (in seconds)
    minEventSize = 0.5;
    
    % Event sampling size (in seconds, the region where it will try to find something and compute statistics).
    % Here you might want to use a small sampling size for neurons or high frequency signals. For glia you might want to use a longer one
    samplingSize = 20;
    end
end
