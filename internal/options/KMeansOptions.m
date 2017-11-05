classdef KMeansOptions < baseOptions
% Optional input parameters for PCA options
%
% See also refineROIthreshold

    properties
        % Number of clusters to use for the K-means
        clusters = 3;

        % Number of iterations for k-means to converge
        iterations = 150;

        % True, to z-norm the features (move them to 0,1 range)
        zNorm@logical = false;

        % Turn nan features into 0s (if false, neurons with missing features
        % will not be used on the PCA analysis, e.g., non-bursting cells)
        nanToZero@logical = true;
    end
end
