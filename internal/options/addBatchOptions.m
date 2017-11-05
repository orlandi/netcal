classdef addBatchOptions < baseOptions
% ADDBATCHOPTIONS Options to add multiple movies at once
%   It will look recursively from the root folder for files with the right
%   extension, and ask which ones needs to be imported
%
%   Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also netcal, baseOptions, optionsWindow

    properties
        % Root folder to look for files
        rootFolder = pwd;
        
        % Extensions of the movies to import
        extension = {'Hamamatsu HIS files (*.HIS)', 'Hamamatsu DCIMG files (*.DCIMG)', 'AVI files (*.AVI)', 'NETCAL experiment (*.EXP)', 'NETCAL binary experiment (*.BIN)', 'quick_dev (*.MAT)', 'CRCNS datasets (*.MAT)', 'Big TIFF files (*.BTF)'};
        
        % If true, will not ask for confirmation on the experiment names. If false, it will ask for confirmation on every single file
        acceptDefaultNames@logical = false;
        
        % If true, will skip any new experiment with repeated names. If
        % false, it will ask to change the name
        skipRepeatedNames@logical = false;
        
        % String to append to each experiment names - leave empty for none
        appendToName = '';
        
        % Tag to append to all the experiments - leave empty for none
        tag = '';
    end
end
