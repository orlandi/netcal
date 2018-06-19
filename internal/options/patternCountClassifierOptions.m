classdef patternCountClassifierOptions < baseOptions
% PATTERNCOUNTCLASSIFIEROPTIONS Options for the pattern count classifier
%   Class containing the parameters to classify traces using a pattern count
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewTraces, baseOptions, optionsWindow

  properties
    % Relative threshold to use for the classifier. You have two options
    % - Between 0 and 1: relative threshold, fraction of events.
    % A threshold of 0.5 with 2 populations means that population will be assigned based on the highest
    % event count. A higher threshold becomes more restrictive, e.g., a threshold of 0.75
    % will only assign a population if 75% of all the events belong to that class. A
    % threshold of 1 will only classify a trace if all events are of the same type.
    % - Bigger than 1: will use absolute counts. A threshold of 5 will look for traces with at least 5 events 
    threshold = 0.5;
    
    % How to classifiy the groups
    % - independent: each trace can only belong to one group
    % - overlapping: each trace can belong to more than one group (as long as the relative threshold condition is met)
    mode = {'independent', 'overlapping'};
  end
end
