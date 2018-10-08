classdef refineROIthresholdOptions < baseOptions
% Optional input parameters for refineROIthreshold
%
% See also refineROIthreshold

    properties
        %Show the ROI before and after refining
        plot@logical = false;

        %Apply a convex hull transformation to each ROI
        convex@logical = true;

        %Minimum number of valid pixels in a ROI
        minimumPixels = 8;

        %Normalized threshold to use (0,1). Any pixel inside a ROI below
        %threshold will be discarded
        threshold = 0.3;
    end
end
