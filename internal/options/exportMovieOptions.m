classdef exportMovieOptions < baseOptions
% Optional input parameters for exportMovieOptions
%     Class containing the options for exporting movies
%   Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also baseOptions, optionsWindow

  properties
    % Desired frame rate of the new movie
    frameRate = 20;

    % Frame jump (jump X amount of frames on each iteration, 1 for no jump)
    jump = 1;

    % Frame range (1 to total number of frames)
    frameRange = [1 inf];

    % Compress movie
    compressMovie = true;
  end
  methods
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment) && isstruct(experiment))
        try
          obj.frameRate = experiment.fps;
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
        try
          obj.frameRange = [1 experiment.numFrames];
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
