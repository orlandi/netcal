function ROI = refineROI(stillImage, ROI, varargin)
% REFINEROI refines the ROI based on the image
%
% USAGE:
%    ROI = refineROI(stillImage, ROI, varargin)
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
% EXAMPLE:
%    ROI = refineROI(stillImage, ROI, varargin)
%
% Copyright (C) 2015, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also autoDetectROI loadExperiment loadROI

params.verbose = true;
params = parse_pv_pairs(params, varargin);

if(params.verbose)
  logMsgHeader('Refining ROI', 'start');
end

logMsg(sprintf('%d ROI found. Looking for overlaps', length(ROI)));

done = false;
foundAnyOverlap = false;
imgSize = size(stillImage);

totalIterations = length(ROI)*(length(ROI)-1)/2;
totalPixelsOverlap = 0;
while(~done)
    done = true;
    if(params.verbose)
        ncbar('Checking for overlaps');
    end
    cit = 0;
    for i = 1:length(ROI)
        for j = (i+1):length(ROI)
            cit = cit + 1;
            % If the ROI are too far apart, don't check for intersections
            if(sqrt((ROI{i}.center(1)-ROI{j}.center(1)).^2 + (ROI{i}.center(2)-ROI{j}.center(2)).^2) < 1.5*(ROI{i}.maxDistance+ROI{j}.maxDistance))
                overlappingPixels = intersect(ROI{i}.pixels, ROI{j}.pixels);
                if(~isempty(overlappingPixels))
                    %if(params.verbose)
                    %    fprintf('Overlap of %d pixels between ROI %d and %d - ', length(overlappingPixels), ROI{i}.ID, ROI{j}.ID);
                    %end
                    totalPixelsOverlap = totalPixelsOverlap + round(length(overlappingPixels)/2);
                    done = false;
                    avgArea = 0.5*(length(ROI{i}.pixels)+length(ROI{j}.pixels));
                    % If too many overlapping pixels, merge
                    if(length(overlappingPixels) > 0.5*avgArea)
                        ROI{i}.pixels = union(ROI{i}.pixels, ROI{j}.pixels);
                        ROI{j}.pixels = [];
                        %if(params.verbose)
                        %    fprintf('merging\n');
                        %end
                        % Else, divide them by proximity to the respective centers
                    else
                        [x_i, y_i] = ind2sub(imgSize, ROI{i}.pixels);
                        [x_j, y_j] = ind2sub(imgSize, ROI{j}.pixels);
                        center_i = [mean(x_i) mean(y_i)];
                        center_j = [mean(x_j) mean(y_j)];
                        allPixels = union(ROI{i}.pixels, ROI{j}.pixels);
                        ROI{i}.pixels = [];
                        ROI{j}.pixels = [];
                        [x_a, y_a] = ind2sub(imgSize, allPixels);
                        dist_i = (x_a-center_i(1)).^2+(y_a-center_i(2)).^2;
                        dist_j = (x_a-center_j(1)).^2+(y_a-center_j(2)).^2;
                        ROI{i}.pixels = allPixels(dist_i <= dist_j);
                        ROI{j}.pixels = allPixels(dist_i > dist_j);
                        %if(params.verbose)
                        %    fprintf('dividing - new sizes: %d and %d \n', length(ROI{i}.pixels), length(ROI{j}.pixels));
                        %end
                    end
                end
            end
            if(params.verbose)
                if(mod(cit,floor(totalIterations/100)) == 0)
                    ncbar.update(cit/totalIterations);
                end
            end
        end
    end
    %done = true;
    if(~done)
        foundAnyOverlap = true;
        if(params.verbose)
            logMsg('Pass not clean. Doing another one');
            ncbar.close();
        end
    else
        if(params.verbose)
            ncbar.close();
        end
    end
end

if(foundAnyOverlap)
    oldNROI = length(ROI);
    invalid = [];
    for i = 1:length(ROI)
        if(isempty(ROI{i}.pixels))
            invalid = [invalid; i];
        end
    end
    ROI(invalid) = [];
    newNROI = length(ROI);
    if(params.verbose)
        logMsg('Found overlaps');
        if(oldNROI > newNROI)
            logMsg(sprintf('%d ROI were removed', oldNROI-newNROI), 'w');
        end
        logMsg(sprintf('%d overlapping pixels were fixed', totalPixelsOverlap), 'w');
    end
else
    if(params.verbose)
        logMsg('No overlaps were found');
    end
end

if(params.verbose)
  logMsgHeader('Done!', 'finish');
end
