classdef obtainPatternBasedFeaturesOptions < baseOptions
% OBTAINPATTERNBASEDFEATURESOPTIONS Predefined options for pattern-matching
%   Options to perform the pattern-matching for trace classification
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also generatePredefinedPatterns

    properties
    % Type of traces to use for the pattern matching
    selectedTracesType = {'raw', 'smoothed'};
    
    % What to do with overlapping events:
    % - correlation: only the event with the highest correlation will be kept
    % - length: only longest event will be kept
    % - none: allows overlapping
    overlappingDiscriminationMethod = {'correlation', 'length', 'none'};
    
    % What kind of discrimination to apply
    % - independent: will try to resolve any kind of overlapping
    % - groupBased: will only resolve overlapping between members of the same group
    overlappingDiscriminationType = {'independent', 'groupBased'};
    end
end
