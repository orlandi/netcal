classdef obtainFeaturesOptions < baseOptions
% Optional input parameters for obtainFeatures
%
% See also obtainFeatures

    properties
    %Divides the signal in chunks and calcualtes features for each chunk. Default: 1
    % Integer - divides the signal equally in so many chunks
    % Vector - Each entry will define a breakpoint for the chunks, .e.g., [0, 100, 600] To have two chunks, one for the first 100 seconds and one from 100 to 600.
    Nepochs = 1;
    
    % Standard deviations above the mean to calculate the features at
    stdThresholdList = [2,2.5,3];
            
    % If true, z-normalize all the features at the end
    zNorm@logical = true;
    end
end
