function out = visualizeROI(stillImage, ROI, varargin)
% VISUALIZEROI shows the contour of the ROI on top of the selected image
%
% USAGE:
%    out = visualizeROI(stillImage, ROI)
%
% INPUT arguments:
%    stillImage - image to show the ROIs on top
%
%    ROI - list of ROI (obtained with loadROI() or autoDetectROI()
%
% INPUT optional arguments ('key' followed by its value):
%    'mode' - 'edge/full/fast' - show only the edges or the full ROI
%
%    'plot' - true/false. If true, shows the image. Default: true
%
%    'color - ' true/false. If true, assigns a random color to each pixel.
%    If false, uses white (pixel intensity = 1)
%
%   'ROIcolorIntensity' - only if color false
%
%   'cmap' - color map to use for the roi
%
% OUTPUT arguments:
%    out - image with the ROI overlapped
%
%
% EXAMPLE:
%    out = visualizeROI(stillImage, ROI)
%
% Copyright (C) 2015-2017, Javier G. Orlandi <javiergorlandi@gmail.com>
% Based on imoverlay
%
% See also autoDetectROI loadROI
params.mode = 'edge';
params.plot = true;
params.color = true;
params.ROIcolorIntensity = [];
params.cmap = [];
params.skipWeights = false;
params = parse_pv_pairs(params, varargin);

% Create a randstream always with the same seed (to replicate colors)
rndStr = RandStream('mt19937ar','Seed',1);

if(params.color)
    % Convert the original image to RGB
    in_uint8 = im2uint8(stillImage);
    out_red   = in_uint8;
    out_green = in_uint8;
    out_blue  = in_uint8;
    if(isempty(params.cmap))
        cmap = hsv(256);
    end
    %perimeterImage = zeros(size(stillImage));
    for i = 1:length(ROI)
      if(strcmp(params.mode, 'edge'))
        tmpImg = zeros(size(stillImage));
        tmpImg(ROI{i}.pixels) = 1;
        newPerimeter = bwperim(tmpImg);
      elseif(strcmp(params.mode, 'edgeHard'))
        tmpImg = zeros(size(stillImage));
        tmpImg(ROI{i}.pixels) = 1;
        perim1 = bwperim(tmpImg);
        se = strel('disk',1);
        nmask = imdilate(tmpImg, se);
        perim2 = bwperim(nmask);
        %se = strel('disk',2);
        %nmask = imdilate(tmpImg, se);
        %perim3 = bwperim(nmask);
        %newPerimeter = perim1+perim2+perim3;
        newPerimeter = perim1+perim2;
        newPerimeter = logical(newPerimeter);
      elseif(strcmp(params.mode, 'full'))
        tmpImg = zeros(size(stillImage));
        tmpImg(ROI{i}.pixels) = 1;
        newPerimeter = logical(tmpImg);
      elseif(strcmp(params.mode, 'fast'))
        newPerimeter = ROI{i}.pixels;
        if(isfield(ROI{i}, 'weights') && ~params.skipWeights)
          newPerimeterWeights = ROI{i}.weights/max(ROI{i}.weights);
        end
      else % Should return error
        newPerimeter = bwperim(tmpImg);
      end
      %currentColor = rand(1,3);
      if(isempty(params.cmap))
        currentColor = cmap(randi(rndStr, length(cmap)), :);
      else
        currentColor = params.cmap(i, :);
      end
      %perimeterImage = perimeterImage + newPerimeter;

      % Replace output channel values in the mask locations with the appropriate
      % color value.
      color_uint8 = im2uint8(currentColor);
      out_red(newPerimeter)   = color_uint8(1);
      out_green(newPerimeter) = color_uint8(2);
      out_blue(newPerimeter)  = color_uint8(3);
      if(isfield(ROI{i}, 'weights') && strcmp(params.mode, 'fast') && ~params.skipWeights)
        out_red(newPerimeter)   = uint8(double(out_red(newPerimeter)).*newPerimeterWeights);
        out_green(newPerimeter) = uint8(double(out_green(newPerimeter)).*newPerimeterWeights);
        out_blue(newPerimeter)  = uint8(double(out_blue(newPerimeter)).*newPerimeterWeights);
      end
    end

    % Form an RGB truecolor image by concatenating the channel matrices along
    % the third dimension.
    out = cat(3, out_red, out_green, out_blue);
else
    out = stillImage;
    for i = 1:length(ROI)
        tmpImg = zeros(size(stillImage));
        tmpImg(ROI{i}.pixels) = 1;
        if(strcmp(params.mode, 'edge'))
            newPerimeter = bwperim(tmpImg);
        elseif(strcmp(params.mode, 'full'))
            newPerimeter = logical(tmpImg);
        else % Should return error
            newPerimeter = bwperim(tmpImg);
        end
        if(isempty(params.ROIcolorIntensity))
            currentColor = max(stillImage(:));
        else
            currentColor = params.ROIcolorIntensity;
        end
        out(newPerimeter) = currentColor;
    end
end
if(params.plot)
    figure;
    warning('off', 'images:initSize:adjustingMag');
    imshow(out);
    warning('on', 'images:initSize:adjustingMag');
    title('ROI');
end