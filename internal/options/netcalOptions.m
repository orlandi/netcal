classdef netcalOptions < baseOptions
% NETCALOPTIONS Global NETCAL options
%   Class containing the global options for NETCAL
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also netcal, baseOptions, optionsWindow

    properties
        % Automatically updates NETCAL (true/false)
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
