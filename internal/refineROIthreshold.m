function ROI = refineROIthreshold(stillImage, ROI, varargin)
% REFINEROITHRESHOLD refines the ROI based on the image
%
% USAGE:
%    ROI = refineROIthreshold(stillImage, ROI, varargin)
%
% INPUT arguments:
%    stillImage - image to use in the ROI refinement
%
%    ROI - ROI list
%
% INPUT optional arguments ('key' followed by its value):
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
%    'minimumPixels' - minimum number of valid pixels in a ROI. Default: 8
%
%    'plot' - (true/false) show the ROI before and after refining. Default: true
%
%    'convex' - (true/false). Apply a convex hull transform to each ROI.
%    Default: true
%
%   'threshold' threshold to use. Default = 0.3
%
% EXAMPLE:
%    ROI = refineROIthreshold(stillImage, ROI, varargin)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also autoDetectROI loadExperiment loadROI

[params, var] = processFunctionStartup(refineROIthresholdOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Refinining ROI thresholds', true);
%--------------------------------------------------------------------------
% 
% if(nargin >= 3 && isa(varargin{1}, 'refineROIthresholdOptions'))
%     params = varargin{1}.get;
%     params = parse_pv_pairs(params, varargin(2:end));
% else
%     params.verbose = true;
%     params.minimumPixels = 8;
%     params.convex = true;
%     params.plot = true;
%     params.threshold = 0.3;
%     params = parse_pv_pairs(params, varargin);
% end

threshold = params.threshold;

testImg = normalizeImage(stillImage);
testImg(testImg < threshold) = 0;
if(params.plot)
    visualizeROI(testImg, ROI);
end

invalid = [];
for i = 1:length(ROI)
    pixels = ROI{i}.pixels;
    validPixels = find(testImg(pixels) > 0);
    nullImg = zeros(size(testImg));
    nullImg(pixels(validPixels)) = 1;
    if(params.convex)
        nullImg = bwconvhull(nullImg);
    end
    res = bwareaopen(nullImg, params.minimumPixels);
    
    validPixels = find(res);
    
    if(length(validPixels) < params.minimumPixels)
        if(params.verbose)
        %    fprintf('ROI %d only has %d valid pixels. Removing\n', i, length(validPixels));
        end
        invalid = [invalid; i];
    else
        %ROI{i}.pixels = pixels(validPixels);
        ROI{i}.pixels = validPixels';
        if(params.verbose)
        %    fprintf('ROI %d contains %d valid pixels (out of %d)\n', i, length(validPixels), length(pixels));
        end
    end
    if(params.pbar > 0)
        ncbar.update(i/length(ROI));
    end

end
if(~isempty(invalid))
    ROI(invalid) = [];
    if(params.verbose)
        logMsg(sprintf('Removed %d invalid ROI', length(invalid)));
    end
end

if(params.plot)
    visualizeROI(normalizeImage(stillImage), ROI);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
