classdef eventSimplificationOptions < baseOptions
% EVENTSIMPLIFICATIONOPTIONS Options for the event simplifier
%   Class containing something
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also viewTraces, baseOptions, optionsWindow

  properties
    % Correlation threshold between events. If any pair of events show a correlation coefficient higher than the threshold, one of them (the longest one) will be removed
    threshold = 0.95;
  end
end
