classdef recordingDriftCorrectionOptions < baseOptions
% RECORDINGDRIFTCORRECTIONOPTIONS ### Correct Recording drift
% This function tries to estimate any drift that appeared on the recording, e.g.,
% sample moving around due to poor adhesion, jittering, vibrations, etc..
% It estimates an affine (rigid) transformation between key frames and tries
% to interpolate between them. As long as the movement is smooth, it should
% work relatively fine. Extremely useful to recover recordings that otherwise
% would be lost.
%
%   Class containing the possible paramters for correcting drift in a recording
%
%   Copyright (C) 2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
%   See also recordingDriftCorrection, baseOptions, optionsWindow

  properties
    % Number of key frames to use to estimate the affine transformations. Transformations between other frames will be linearly interpolated. Leave empty to use all frames
    numberKeyFrames = 100;

    % Each key frame will be averaged with the following X frames. Empty 0 or 1 for no averaging at all
    keyFrameAverage = 10;

    % Frame number to use as reference, i.e., all movement will be computed based on this frame
    referenceFrame = 1;
    
    % If true, will use information from the previous alignment to compute a new one. If not, it will always start from the original image
    iterativeAlignment = false;
    
    % What kind of transformation to apply:
    % rigid: includes translations and rotations
    % translation: only translations (no rotations)
    % similarity: translations rotations and scaling (not recommended if interpolation is used, i.e., numberKeyFrames less than the total number of frames)
    % affine: translations rotations scaling and shear (not recommended if interpolation is used, i.e., numberKeyFrames less than the total number of frames)
    % subpixelDFT: subpixel DFT-based registration - see dftregistration for details
    transformationType = {'rigid', 'translation', 'similarity', 'affine', 'subpixelDFT'};
    
    % Level of upsampling for DFT computation (only for transformationType = subpixelDFT), e.g., 20 for 1/20 pixel resolution
    subPixelResolution = 20;
    
    % Type of interpolation to perform when warping the resulting image
    % subpixelDFT: it will use the inverse output from subpixelDFT rather
    % than an image warp (only useful if the transformation was subpixelDFT
    % and no averaging was used)
    interpolationType = {'cubic', 'linear', 'nearest', 'subpixelDFT'};
    
    % If true, will activate the transformation, and any function that tries to recover a frame will apply the correction first. If this is disabled
    % no transformation will be applied. Ever.
    enableResultingTransformation = true;
    
    % If the maximum displacement from the origin is below this value (in pixels), the transformation will be disabled by default
    minimumDisplacement = 1;
    
    % If true, will plot the drift trajectory
    plotTrajectory = true;
    
    % If true, will show the last transformation on top of the first one
    plotFinalTransformation = true;
  end
end
