function outputImage = normalizeImage(inputImage, varargin)
% NORMALIZEIMAGE rescale image data to the (0, 1) range
%
% USAGE:
%    ouputImage = normalizeImage(image)
%
% INPUT arguments:
%    inputImage - matrix with data
%
% INPUT optional arguments ('key' followed by its value):
%    'lowerSaturation' - [0,100]. % of pixels to sature on the lower end of
%    the histogram. Default: 0
%
%    'upperSaturation' - [0,100]. % of pixels to sature on the upper end of
%    the histogram. Default: 0
%
%   'intensityRange - [min,max]. If not empty, will saturate everything
%   outside of this range. Default: empty
%
%    'plot' - (true/false). Plots the resulting image. Default: false
%
% OUTPUT arguments:
%    ouputImage - normalized matrix
%
% EXAMPLE:
%     ouputImage = normalizeImage(inputImage);
%
% REFERENCES:
%
% Copyright (C) 2015, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.lowerSaturation = 0;
params.upperSaturation = 0;
params.intensityRange = [];
params.plot = false;
params = parse_pv_pairs(params, varargin);

inputImage = double(inputImage);
if(params.lowerSaturation == 0 && params.upperSaturation == 0 && isempty(params.intensityRange))
    outputImage = (inputImage - min(inputImage(:)))/(max(inputImage(:))-min(inputImage(:)));
elseif(isempty(params.intensityRange))
    [sortedPixels, idx] = sort(inputImage(:), 'ascend');
    pixelsBelowThreshold = round(length(sortedPixels)*params.lowerSaturation/100);
    pixelsAboveThreshold = round(length(sortedPixels)*params.upperSaturation/100);
    minIntensity = sortedPixels(pixelsBelowThreshold+1);
    maxIntensity = sortedPixels(length(sortedPixels)-(pixelsAboveThreshold+1));
    outputImage = inputImage;
    outputImage(idx(1:pixelsBelowThreshold)) = minIntensity;
    outputImage(idx((length(sortedPixels)-pixelsAboveThreshold):end)) = maxIntensity;
    outputImage = (outputImage - min(outputImage(:)))/(max(outputImage(:))-min(outputImage(:)));
else
    minIntensity = params.intensityRange(1);
    maxIntensity = params.intensityRange(2);
    outputImage = inputImage;
    outputImage(outputImage < minIntensity) = minIntensity;
    outputImage(outputImage > maxIntensity) = maxIntensity;
    
    %outputImage = (outputImage - min(outputImage(:)))/(max(outputImage(:))-min(outputImage(:)));
    outputImage = (outputImage - minIntensity)/(maxIntensity-minIntensity);
end

if(params.plot)
    figure;
    warning('off', 'images:initSize:adjustingMag');
    imshow(outputImage);
    warning('on', 'images:initSize:adjustingMag');
    title('Normalized image');
end
