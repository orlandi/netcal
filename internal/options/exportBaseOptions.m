classdef exportBaseOptions < baseOptions
% EXPORTBASEOPTIONS Base options for exporting data
%   Class containing the base options for exporting data
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also baseOptions, optionsWindow

  properties
    % Export type
    exportType = {'csv', ''};
    
    % True to deleted old file. If false, and writing to excel files, the data will override entries in the specified sheet
    deleteOldFile = true;
    
    % Tag to append to the name of the exported file
    exportFileTag = '';
  end
end
