function ROI = loadROI(experiment, filename, varargin)
% LOADROI loads the ROIs from an external file for a given experiment
%
% USAGE:
%    ROI = loadROI(experiment, filename)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
%    filename - external file
%
% INPUT optional arguments ('key' followed by its value):
%    'mode' - 'square/raw/auto'. 'square': loads ROI from a file whose columns
%    are: | ID | X | Y | Width | , where X,Y are the pixels of the center
%    of a square with width Width (floor(Width/2)). 'raw': ID followed by
%    pairs of X,Y pixel coordinates. Auto: tries to guess it. Default: 'auto'.
%
%    'relativePath' - true/false. If true, will check for the ROI file in
%    the same folder as the HIS file. Default = true;
%
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
% EXAMPLE:
%    ROI = loadROI(experiment, filename)
%
% Copyright (C) 2015-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also autoDetectROI loadExperiment

params.mode = 'auto';
params.verbose = true;
params.relativePath = false;
params.overwriteMode = [];
params = parse_pv_pairs(params, varargin);

if(params.verbose)
  logMsgHeader('Loading ROI from file', 'start');
end

if(params.relativePath)
    fpa = experiment.folder;
    filename = [fpa filesep filename];
end

ROIdata = load(filename);
width = experiment.width;
height = experiment.height;
if(strcmp(params.mode, 'auto'))
    if(size(ROIdata,2) == 4)
        params.mode = 'square';
        logMsg('Square ROI file detected');
    else
        params.mode = 'raw';
        logMsg('Raw ROI file detected');
    end
end
if(~isempty(params.overwriteMode))
  params.mode = params.overwriteMode;
end
if(strcmp(params.mode, 'square'))
    if(size(ROIdata,2) ~= 4)
        logMsg('File structure incompatible with mode square', 'e');
        ROI = [];
        return;
    end
    N = size(ROIdata,1);
    ROI = cell(N, 1);
    for i = 1:N
        ID = ROIdata(i, 1);
        x = ROIdata(i, 2);
        y = ROIdata(i, 3);
        ROIwidth = ROIdata(i, 4);
        
        first_x = x - floor(ROIwidth/2) + 1;
        last_x = x + ceil(ROIwidth/2);
        first_y = y - floor(ROIwidth/2) + 1;
        last_y = y + ceil(ROIwidth/2);
        
        % Bounds check
        first_x = max(1, first_x);
        first_y = max(1, first_y);
        last_x = min(width, last_x);
        last_y = min(height, last_y);
        
        range_x = first_x:last_x;
        range_y = first_y:last_y;
        pixels = combvec(range_y, range_x);
        
        ROI{i}.ID = ID;
        ROI{i}.pixels = sub2ind([height width], pixels(1,:), pixels(2,:));
        ROI{i}.center = [mean(range_x), mean(range_y)];
        ROI{i}.maxDistance = max(sqrt((ROI{i}.center(1)-pixels(2,:)).^2+(ROI{i}.center(2)-pixels(1,:)).^2));
        
    end
elseif(strcmp(params.mode, 'raw'))
    N = size(ROIdata,1);
    ROI = cell(N, 1);
    for i = 1:N
        ID = ROIdata(i, 1);
        y = ROIdata(i, 2:2:size(ROIdata,2));
        x = ROIdata(i, 3:2:size(ROIdata,2));
        y = y(~isnan(x));
        x = x(~isnan(y));
        ROI{i}.ID = ID;
        ROI{i}.pixels = sub2ind([height width], y, x);
        ROI{i}.center = [mean(x), mean(y)];
        ROI{i}.maxDistance = max(sqrt((ROI{i}.center(1)-x).^2+(ROI{i}.center(2)-y).^2));
    end
elseif(strcmp(params.mode, 'rawNew'))
    N = size(ROIdata,1);
    ROI = cell(N, 1);
    for i = 1:N
        ID = ROIdata(i, 1);
        %x = ROIdata(i, 2:2:size(ROIdata,2));
        %y = ROIdata(i, 3:2:size(ROIdata,2));
        Npixels = (size(ROIdata,2)-1)/2;
        y = ROIdata(i, 2:(1+Npixels));
        x = ROIdata(i, (2+Npixels):end);
        y = y(~isnan(y));
        x = x(~isnan(x));
        %valid = find(~isnan(x) & ~isnan(y));
        %x = x(valid);
        %y = y(valid);
        ROI{i}.ID = ID;
        ROI{i}.pixels = sub2ind([height width], y, x);
        ROI{i}.center = [mean(x), mean(y)];
        ROI{i}.maxDistance = max(sqrt((ROI{i}.center(1)-x).^2+(ROI{i}.center(2)-y).^2));
    end
else
    logMsg('Invalid mode. Use square or raw', 'e');
    ROI = [];
    return;
end

if(params.verbose)
  logMsg([num2str(length(ROI)) ' ROI loaded']);
  logMsgHeader('Done!', 'finish');
end

