function ROI = autoDetectROI(stillImage, varargin)
% AUTODETECTROI automatically tries to detect regions of interest from the
% experiment
%
% USAGE:
%    ROI = autoDetectROI(experiment, image)
%
% INPUT arguments:
%   avgImg - the image to use
%
% INPUT optional arguments ('key' followed by its value):
%
%   ROIautomaticOptions - options class
%
% EXAMPLE:
%    ROI = autoDetectROI(image, ROIautomaticOptions)
%
% Copyright (C) 2015, Javier G. Orlandi <javierorlandi@javierorlandi.com>

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(ROIautomaticOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, ['Autodetecting ROI: ' strrep(params.automaticType,'_','-')]);
%--------------------------------------------------------------------------

if(params.removeBackgroundFirst)
  stillImage = round((2^8-1)*(normalizeImage(stillImage, 'lowerSaturation', 0.2, 'upperSaturation', 0.3)));
  stillImage = stillImage - imgaussfilt(stillImage, params.sizeAutomaticCellSize/2);
  stillImage(stillImage <0) = 0;
end

switch params.automaticType
  case 'threshold'
  if(params.pbar > 0)
    ncbar.setAutomaticBar();
  end
    % Remove dead pixels
    if(params.removeDeadPixels)
      me = mean(double(stillImage(:)));
      se = std(double(stillImage(:)));
      deadPixels = find(stillImage > me+params.deadPixelMultiplier*se);
      stillImage(deadPixels) = NaN;
      logMsg(sprintf('%d dead pixels removed', length(deadPixels)));
    end

    normalizedStillImage = (stillImage-min(stillImage(:)))/(max(stillImage(:))-min(stillImage(:)));

    filteredImg = normalizedStillImage;
    filteredImg(filteredImg < params.sizeAutomaticThreshold) = 0;
    filteredImg(filteredImg > params.sizeAutomaticThreshold) = 1;

    filteredImg(isnan(filteredImg))=0;
    bw2 = imfill(filteredImg,'holes'); 
    bw3 = imopen(bw2, ones(4,4)); 
    bw4 = bwareaopen(bw3, 10); 
    bw4_perim = bwperim(bw4); 

    B = bwconncomp(bw4);

    ROI = cell(B.NumObjects, 1);

    for i = 1:length(ROI)
      if(params.pbar > 0)
        ncbar.update(i/length(ROI));
      end
      ROI{i}.ID = i;
      ROI{i}.pixels = B.PixelIdxList{i}';
      [y, x] = ind2sub(size(normalizedStillImage), ROI{i}.pixels);
      ROI{i}.center = [mean(x), mean(y)];
      ROI{i}.maxDistance = max(sqrt((ROI{i}.center(1)-x).^2+(ROI{i}.center(2)-y).^2));
    end

  % Based on Fernando's code. Adding active contour and fast smoothing
  case 'quick_dev'
    if(params.pbar > 0)
      ncbar.setAutomaticBar();
    end

    if(params.removeDeadPixels)
      me = mean(double(stillImage(:)));
      se = std(double(stillImage(:)));
      deadPixels = find(stillImage > me+params.deadPixelMultiplier*se);
      stillImage(deadPixels) = NaN;
      logMsg(sprintf('%d dead pixels removed', length(deadPixels)));
    end
    objSize = params.sizeAutomaticCellSize;
    frame = stillImage;
    switch params.filterType
      case 'median'
        frame = frame - medfilt2(frame, [objSize objSize]);
      case 'gaussian'
        frame = frame - imgaussfilt(frame, objSize);
      case 'none'
    end

    frame(frame < 0) = 0;
    frame = uint16(frame);

    no_back = frame - imopen(frame, strel('ball', objSize, objSize, 0));
    no_back_bw = imopen(no_back > 0, strel('disk', 1, 0));

    % Add active contour calculations
    no_back_bw = activecontour(frame,no_back_bw);

    CC = bwconncomp(no_back_bw, 4);
    PROPS = regionprops(CC, 'Solidity', 'Centroid', 'Area', 'BoundingBox');

    if(params.pbar > 0)
      ncbar.unsetAutomaticBar();
      ncbar.setCurrentBarName('Processing objects');
    end

    ROI = [];
    currROI = 1;
    % area size to ignore
    %cell_area_ignore = max(9, (objSize/4-1)^2);
    cell_area_ignore = max(9, (objSize/2-1)^2);

    for i=1:CC.NumObjects
      if(params.pbar > 0)
        ncbar.update(i/CC.NumObjects);
      end
      cc = CC.PixelIdxList{i};
      props = PROPS(i);

      single_cell = 1;
      if props.Solidity < 0.9
        % we will need to work with the base frame
        img = frame;

        % mask out everything else
        BW = xor(img,img);
        BW(cc) = 1;
        %BW = imfill(BW,4,'holes'); % Fill holes
        [vr, vc] = find(BW);
        vr = unique(vr);
        vc = unique(vc);
        BW(vr,vc) = imfill(BW(vr,vc),4,'holes'); % Fill holes
        
        img(~BW) = 0;

        % find the components for only this image
        CC_m = bwconncomp(img > median(img(BW)), 4);

        % if we indeed have more than one cell
        if CC_m.NumObjects > 1
          PROPS_m = regionprops(CC_m, ...
              'Solidity', 'Centroid', 'Area', 'BoundingBox');
          single_cell = 0;

          for k=1:CC_m.NumObjects
            cc = CC_m.PixelIdxList{k};
            props = PROPS_m(k);
            if props.Area < cell_area_ignore
                continue
            end
            %cells = [cells;create_cell(cc, props, frame)];
            ROI{currROI}.ID = currROI;

            BW = zeros(size(frame));
            BW(cc) = 1;
            %BW = imfill(BW,4,'holes'); % Fill holes
            [vr, vc] = find(BW);
            vr = unique(vr);
            vc = unique(vc);
            BW(vr,vc) = imfill(BW(vr,vc),4,'holes'); % Fill holes

            ROI{currROI}.pixels = find(BW);
            [y, x] = ind2sub(size(stillImage), ROI{currROI}.pixels);
            ROI{currROI}.center = [mean(x), mean(y)];
            ROI{currROI}.maxDistance = max(sqrt((ROI{currROI}.center(1)-x).^2+(ROI{currROI}.center(2)-y).^2));
            currROI = currROI + 1;
          end % new cells
        end % more than one cells
      end % possible more than one cell

      % skip if we are not big enough
      if props.Area < cell_area_ignore
        continue;
      end

      if single_cell
        ROI{currROI}.ID = currROI;

        BW = zeros(size(frame));
        BW(cc) = 1;
        %BW = imfill(BW,4,'holes'); % Fill holes
        [vr, vc] = find(BW);
        vr = unique(vr);
        vc = unique(vc);
        BW(vr,vc) = imfill(BW(vr,vc),4,'holes'); % Fill holes

        ROI{currROI}.pixels = find(BW);
        [y, x] = ind2sub(size(stillImage), ROI{currROI}.pixels);
        ROI{currROI}.center = [mean(x), mean(y)];
        ROI{currROI}.maxDistance = max(sqrt((ROI{currROI}.center(1)-x).^2+(ROI{currROI}.center(2)-y).^2));
        currROI = currROI + 1;
      end
    end
    
    ROI = ROI';
  case 'splitThreshold'
    if(params.pbar > 0)
      ncbar.setAutomaticBar();
    end
    % Remove dead pixels
    if(params.removeDeadPixels)
      me = mean(double(stillImage(:)));
      se = std(double(stillImage(:)));
      deadPixels = find(stillImage > me+params.deadPixelMultiplier*se);
      stillImage(deadPixels) = NaN;
      logMsg(sprintf('%d dead pixels removed', length(deadPixels)));
    end

    normalizedStillImage = (stillImage-min(stillImage(:)))/(max(stillImage(:))-min(stillImage(:)));

    filteredImg = normalizedStillImage;
    filteredImg(filteredImg < params.sizeAutomaticThreshold) = 0;
    filteredImg(filteredImg > params.sizeAutomaticThreshold) = 1;

    filteredImg(isnan(filteredImg))=0;
    frame = filteredImg;
    bw2 = imfill(filteredImg,'holes'); 
    bw3 = imopen(bw2, ones(4,4)); 
    bw4 = bwareaopen(bw3, 10); 
    bw4_perim = bwperim(bw4); 

    CC = bwconncomp(bw4, 4);
    PROPS = regionprops(CC, 'Solidity', 'Centroid', 'Area', 'BoundingBox');

    if(params.pbar > 0)
      ncbar.unsetAutomaticBar();
      ncbar.setCurrentBarName('Processing objects');
    end

    ROI = [];
    currROI = 1;
    % area size to ignore
    %cell_area_ignore = max(9, (objSize/4-1)^2);
    objSize = params.sizeAutomaticCellSize;
    cell_area_ignore = max(9, (objSize/2-1)^2);
    invalidROI = 0;

    for i=1:CC.NumObjects
      if(params.pbar > 0)
          ncbar.update(i/CC.NumObjects);
      end
      cc = CC.PixelIdxList{i};
      
      props = PROPS(i);

      single_cell = 1;
      if props.Solidity < 0.9
        % This is not working
        % we will need to work with the base frame
        img = normalizedStillImage;

        % mask out everything else
        %BW = zeros(size(img), 'gpuArray');
        BW = zeros(size(img));
        BW(cc) = 1;
        [vr, vc] = find(BW);
        vr = unique(vr);
        vc = unique(vc);
        BWn = false(size(img));
        BWn(vr,vc) = ~~imfill(BW(vr,vc),4,'holes'); % Fill holes
        img(~BWn) = 0;

        % find the components for only this image
        CC_m = bwconncomp(img > median(img(BWn)), 4);

        % if we indeed have more than one cell
        if CC_m.NumObjects > 1
          PROPS_m = regionprops(CC_m, ...
            'Solidity', 'Centroid', 'Area', 'BoundingBox');
          single_cell = 0;

          for k=1:CC_m.NumObjects
            cc = CC_m.PixelIdxList{k};
            props = PROPS_m(k);
            if props.Area < cell_area_ignore
              invalidROI = invalidROI + 1;
              continue
            end
            %cells = [cells;create_cell(cc, props, frame)];
            ROI{currROI}.ID = currROI;

            %BW = zeros(size(frame), 'gpuArray');
            BW = zeros(size(frame));
            BW(cc) = 1;
            %BWA = gpuArray(BW);
            
            %BWn = imfill(BW,4,'holes'); % Fill holes
            [vr, vc] = find(BW);
            vr = unique(vr);
            vc = unique(vc);
            BWn = false(size(frame));
            BWn(vr,vc) = ~~imfill(BW(vr,vc),4,'holes'); % Fill holes

            ROI{currROI}.pixels = find(BWn);
            [y, x] = ind2sub(size(stillImage), ROI{currROI}.pixels);
            ROI{currROI}.center = [mean(x), mean(y)];
            ROI{currROI}.maxDistance = max(sqrt((ROI{currROI}.center(1)-x).^2+(ROI{currROI}.center(2)-y).^2));
            currROI = currROI + 1;
          end % new cells
        end % more than one cells
      end % possible more than one cell

      % skip if we are not big enough
      if props.Area < cell_area_ignore
        invalidROI = invalidROI + 1;
        continue
      end

      if single_cell
        ROI{currROI}.ID = currROI;

        BW = zeros(size(frame));
        BW(cc) = 1;
        %BW = imfill(BW,4,'holes'); % Fill holes
        [vr, vc] = find(BW);
        vr = unique(vr);
        vc = unique(vc);
        BWn = false(size(frame));
        BWn(vr,vc) = ~~imfill(BW(vr,vc),4,'holes'); % Fill holes

        ROI{currROI}.pixels = find(BW);
        [y, x] = ind2sub(size(stillImage), ROI{currROI}.pixels);
        ROI{currROI}.center = [mean(x), mean(y)];
        ROI{currROI}.maxDistance = max(sqrt((ROI{currROI}.center(1)-x).^2+(ROI{currROI}.center(2)-y).^2));
        currROI = currROI + 1;
      end
    end
  ROI = ROI';
  logMsg(sprintf('%d ROI found (%d before splitting and minimum area checks, %d too small). ', length(ROI), CC.NumObjects, invalidROI));
end

if(params.verbose)
  logMsg(sprintf('%d ROI found', length(ROI)));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------