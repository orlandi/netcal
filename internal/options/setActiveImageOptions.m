classdef setActiveImageOptions < baseOptions
% SETACTIVEIMAGE Sets the active image. This will be the default image
% NETCAL uses when needed (usually for viewing the recording, defining
% ROis, etc)
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also setActiveNetwork, baseOptions, optionsWindow

  properties
    % File to use:
    % - average fluorescence: The avearge fluorescence image (computed on the preprocessing step)
    % - external file: a different image (change it on externalFile)
    selection = {'average fluorescence', 'external file'};
      
    % External file to use
    externalFile = [pwd filesep 'defaultImage.tif'];
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.externalFile = [experiment.folder filesep 'defaultImage.tif'];
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder');
        obj.externalFile = [exp.folder filesep 'defaultImage.tif'];
      end
    end
  end
end
