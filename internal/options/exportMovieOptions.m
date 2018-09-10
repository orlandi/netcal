classdef exportMovieOptions < baseOptions
% Optional input parameters for exportMovieOptions
%   Class containing the options for exporting movies
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also baseOptions, optionsWindow

  properties
    % Desired frame rate of the new movie
    frameRate = 20;

    % Resampling method. Use this if you want the movie to play at real
    % time but with a smaller frame rate than the original
    % - none: Will not do anything
    % - sum: Will add together all frames involved in the new frame (only for downsampling). This might result in dynamic range clipping.
    % - average: Same as sum, but dividing (only for downsampling). This might result in quality reduction due to rounding errors (for integer data).
    resamplingMethod = {'none', 'sum', 'mean'};
    
    % Frame skip (if no resampling). Will skip X number of frames on each iteration, 1 or empty for no skip)
    frameSkip = 1;

    % How to select the range of the movie (affects the range parameter)
    % - frames: range is given in frames (starts at 1)
    % - time: range is given in seconds (starts at 0)
    rangeSelection = {'frames', 'time'};
    
    % Range (see rangeSelection)
    range = [1 inf];
    
    % Profile to use.
    profile = {'Big Tiff', 'Archival', 'Uncompressed AVI', 'Grayscale AVI', 'Motion JPEG AVI', 'Motion JPEG 2000', 'MPEG-4'};
    
    % Bits per pixel of the new movie (8, 16, 32) - not all profiles will
    % be compatible
    bitsPerPixel = {'16', '8', '32', 'single', 'double'};
    
    % If the movie should be compressed (only if the profile allows it)
    compressMovie = true;
    
    % Level of compression (0 for lossless. Use valuees larger than 1 for lossy compression)
    compressionLevel = 0;
    
    % Filename of the new movie
    baseFileName = 'exportMovie';
    
    % If true, will rescale everything to previous estimates of minimum and maximum intensity values. Only works if the movie has already been preprocessed
    maximizeDynamicRange = false;
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
          obj.range = [1 experiment.numFrames];
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      elseif(~isempty(experiment) && exist(experiment, 'file'))
        exp = load(experiment, '-mat', 'folder', 'name', 'fps', 'numFrames');
        try
          obj.frameRate = exp.fps;
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
        try
          obj.range = [1 exp.numFrames];
        catch ME
          logMsg(strrep(getReport(ME), sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
