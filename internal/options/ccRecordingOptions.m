classdef ccRecordingOptions < baseOptions
% CCRECORDINGOPTIONS Options fo a camControl recording
%   Class containing the options for a new recording
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also camControl, baseOptions, optionsWindow

  properties
    % Name and location of the base recording file (WITHOUT extension)
    recordingName = [pwd filesep 'recording'];
    
    % Frames per second of the recording
    FPS = 10;
    
    % Recording length (in seconds)
    recordingLength = 300;
    
    % If all traces should be kept in memory and visualized
    bufferAllTraces@logical = true;
    
    % Traces update rate (1 out of every X captured frames) You can use it
    % for visualization purposes if you have too many ROIs for your
    % computer. But you will need to extract the traces again within
    % netcal. This only works for bufferAllTraces = true
    recordingFrameRateStepSize = 1;
    
    % If the movie itself should be stored
    saveMovie@logical = true;
    
    % To also generate an average image from the low intensity pixels
    computeLowerPercentileTrace@logical = false;
    
    % Percentile where to cut the distribution for the low average image (0 to 100)
    lowerPercentile = 1;
    
    % Why didn't this show up?
    disableTraceUpdates = false;
    
    % To write the output movie in multiple drives (use at your own risk)
    numberOfDrives = {'1', '2', '3', '4'};
    
    % Folder to store the video in the second drive (only used when numberOfDrives >= 2)
    secondDriveFolder = [pwd filesep];
    
    % Folder to store the video in the third drive (only used when numberOfDrives >= 3)
    thirdDriveFolder = [pwd filesep];
    
    % Folder to store the video in the fourth drive (only used when numberOfDrives >= 4)
    fourthDriveFolder = [pwd filesep];
    
    % To generate the glia movie data (moving average of the original recording)
    generateGliaMovie@logical = false;
    
    % Glia movie: Number of frames to average
    windowSize = 50;

    % Glia movie: Number of frames to overlap between consecutive averaged frames
    windowOverlap = 25;

    % Glia movie: Spatial smoothing kernel to apply to each frame
    smoothingKernel = 'fspecial(''gaussian'', [3 3])';

    % Glia movie: Rescale original image size by this factor (1 to keep original size, 0.5 to reduce size by half)
    imageRescalingFactor = 1;
    
  end
  methods 
    function obj = setExperimentDefaults(obj, experiment)
      if(~isempty(experiment))
        try
          %obj.splineDivisionLength = min([25 round(round(experiment.totalTime)/2)]);
          %obj.blockLength = min([25 round(round(experiment.totalTime)/2)]);
        catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
    function obj = setProjectDefaults(obj, project)
      if(~isempty(project))
        try
          obj.recordingName = fullfile(project.folder, 'recording');
          %obj.splineDivisionLength = min([25 round(round(experiment.totalTime)/2)]);
          %obj.blockLength = min([25 round(round(experiment.totalTime)/2)]);
        catch ME
            logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
        end
      end
    end
  end
end
