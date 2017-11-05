classdef plotAverageTraceOptions < baseOptions
% PLOTAVERAGETRACEOPTIONS Base options for plotting the average trace
%   Class containing the base options for plotting the average trace
%
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % Group to extract the traces from:
    % - none: will export all traces
    % - all: will recursively export throughout all defined groups
    % - group parent: will iterate through all its members
    % - group member: will only return the traces from this group member
    group = {'none', ''};
  end
end
