classdef netcalOptions < baseOptions
% NETCALOPTIONS # Global preferences
%   Set of options that affect NETCAL global's behavior
%
%   Copyright (C) 2016-2017, Javier G. Orlandi
%
%   See also netcal, baseOptions, optionsWindow

  properties
    % How to update NETCAL:
    % - always: always try to update
    % - ask: will ask for confirmation if a new update is found
    % - never: will never check for updates
    update = {'always', 'ask', 'never'};

    % Default folder to look for projects
    defaultFolder = pwd;

    % Number of recent projects to display in the load menu
    numberRecentProjects = 5;

    % Main font size to use across the program (partially supported and requires program restart)
    mainFontSize = 12;

    % Header font size to use across the program (partially supported and requires program restart)
    headerFontSize = 12;

    % Tree font size to use across the program (partially supported and requires program restart)
    treeFontSize = 12;

    % Default font size for UI controls (partially supported and requires program restart)
    uiFontSize = 12;
  end
end
