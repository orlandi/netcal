function experiment = cleanROIfromCellSort(experiment, varargin)
% CLEANROIFROMCELLSORT cleans ROI from cellSort procedure. As a side effect it also extracts traces
%
% USAGE:
%    experiment = cleanROIfromCellSort(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: cleanROIfromCellSortOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = cleanROIfromCellSort(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: clean ROI from CellSort and trace extraction
% parentGroups: fluorescence: cellSort
% optionsClass: cleanROIfromCellSortOptions
% requiredFields: ROI

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(cleanROIfromCellSortOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them

params = parse_pv_pairs(params, var);
params = barStartup(params, 'Cleaning ROI from CellSort');
%--------------------------------------------------------------------------

corThreshold = params.correlationThreshold;
overlappingThreshold = params.overlappingThreshold;
pixelLeeway = params.pixelLeeway;
forceOverlap = params.forceOverlap;
extractTracesOptionsCurrent = extractTracesOptions;
extractTracesOptionsCurrent = extractTracesOptionsCurrent.setDefaults();
extractTracesOptionsCurrent.subset = params.subset;

% Store previous options
if(isfield(experiment, 'extractTracesOptionsCurrent'))
  oldExtraction = experiment.extractTracesOptionsCurrent;
else
  oldExtraction = [];
end
experiment.extractTracesOptionsCurrent = extractTracesOptionsCurrent;
if(params.fast)
  experiment.extractTracesOptionsCurrent.fast = true;
else
  experiment.extractTracesOptionsCurrent.fast = false;
end

numROI = length(experiment.ROI);
% First pass to merge fully overlapping ROIs
if(params.pbar > 0)
  ncbar.setCurrentBarName('Merging ROI by maximum overlap');
end
curIt = 0;
fullyDone = false;
while(~fullyDone)
  newROI = experiment.ROI;
  if(params.pbar > 0)
    ncbar.update(0);
  end
  fullyDone = true;
  curIt = curIt + 1;
  if(params.pbar > 0)
    ncbar.setCurrentBarName(sprintf('Merging ROI by maximum overlap. Current iteration: %d', curIt));
    ncbar.update(0);
  end
  
  partIt = 0;
  for it1 = 1:length(newROI)
    done = false;
    while(~done)
      done = true;
      % In case of merge, we always delete 2nd ROI. Never the first
      for it2 = (it1+1):length(newROI)
        % Quick distance check
        %if(newROI{it1}.center-newROI{it2}.center
        if(sqrt(sum((newROI{it1}.center-newROI{it2}.center).^2)) > newROI{it1}.maxDistance+newROI{it2}.maxDistance+pixelLeeway) % 5 pixels leeway
          continue;
        end
        mask = zeros(experiment.height, experiment.width);
        mask(newROI{it1}.pixels) = 1;
        mask(newROI{it2}.pixels) = 1;
        CC = bwconncomp(mask, 4);
        if(CC.NumObjects == 1)
          %R = corrcoef(experiment.rawTraces(:, it1), experiment.rawTraces(:, it2));
          R = length(intersect(newROI{it1}.pixels, newROI{it2}.pixels))/min(length(newROI{it1}.pixels), length(newROI{it2}.pixels));
          if(R >= overlappingThreshold)
            %numPixels1 = length(newROI{it1}.pixels);
            %oldID1 = newROI{it1}.ID;
            %numPixels2 = length(newROI{it2}.pixels);
            %oldID2 = newROI{it2}.ID;
            mask = zeros(experiment.height, experiment.width);
            mask(newROI{it1}.pixels) = newROI{it1}.weights;
            mask(newROI{it2}.pixels) = mask(newROI{it2}.pixels)+newROI{it2}.weights;
            % Reassign
            newROI{it1}.pixels = find(mask);
            newROI{it1}.weights = mask(newROI{it1}.pixels);
            [y, x] = ind2sub(size(mask), newROI{it1}.pixels);
            newROI{it1}.center = [mean(x), mean(y)]; % Same as the centroid
            newROI{it1}.maxDistance = max(sqrt((newROI{it1}.center(1)-x).^2+(newROI{it1}.center(2)-y).^2));
            %fprintf('Merging ROIs %d and %d. Overlap: %.3f. Old sizes: %d %d. New size: %d. ROI left: %d\n', oldID1, oldID2, R, numPixels1, numPixels2, length(newROI{it1}.pixels), length(newROI));
            newROI(it2) = [];
            done = false;
            fullyDone = false;
            break;
          end
        end
      end
    end
    partIt = partIt + length(newROI)-(it1-1);
    if(params.pbar > 0)
      ncbar.update(2*partIt/(length(newROI)*(length(newROI)-1)));
    end
  end
  experiment.ROI = newROI;
end

if(params.pbar > 0)
  ncbar.setCurrentBarName('Merging ROI by maximum correlation');
end
curIt = 0;
fullyDone = false;
while(~fullyDone)
  newROI = experiment.ROI;
  if(params.pbar > 0)
    ncbar.update(0);
  end
  
  experiment = extractTraces(experiment, experiment.extractTracesOptionsCurrent, 'pbar', params.pbar);
  experiment = loadTraces(experiment, 'raw', 'pbar', params.pbar);
  fullyDone = true;
  curIt = curIt + 1;
  if(params.pbar > 0)
    ncbar.setCurrentBarName(sprintf('Merging ROI by maximum correlation. Current iteration: %d', curIt));
    ncbar.update(0);
  end
  partIt = 0;
  for it1 = 1:length(newROI)
    done = false;
    while(~done)
      done = true;
      % In case of merge, we always delete 2nd ROI. Never the first
      for it2 = (it1+1):length(newROI)
        % Quick distance check
        %if(newROI{it1}.center-newROI{it2}.center
        if(sqrt(sum((newROI{it1}.center-newROI{it2}.center).^2)) > newROI{it1}.maxDistance+newROI{it2}.maxDistance+pixelLeeway)
          continue;
        end
        mask = zeros(experiment.height, experiment.width);
        mask(newROI{it1}.pixels) = 1;
        mask(newROI{it2}.pixels) = 1;
        if(forceOverlap)
          CC = bwconncomp(mask, 4);
          valid = CC.NumObjects == 1;
        else
          valid = true;
        end
        if(valid)
          R = corrcoef(experiment.rawTraces(:, it1), experiment.rawTraces(:, it2));
          if(R(1,2) >= corThreshold)
%             numPixels1 = length(newROI{it1}.pixels);
%             oldID1 = newROI{it1}.ID;
%             numPixels2 = length(newROI{it2}.pixels);
%             oldID2 = newROI{it2}.ID;
            mask = zeros(experiment.height, experiment.width);
            mask(newROI{it1}.pixels) = newROI{it1}.weights;
            mask(newROI{it2}.pixels) = mask(newROI{it2}.pixels)+newROI{it2}.weights;
            % Reassign
            newROI{it1}.pixels = find(mask);
            newROI{it1}.weights = mask(newROI{it1}.pixels);
            [y, x] = ind2sub(size(mask), newROI{it1}.pixels);
            newROI{it1}.center = [mean(x), mean(y)]; % Same as the centroid
            newROI{it1}.maxDistance = max(sqrt((newROI{it1}.center(1)-x).^2+(newROI{it1}.center(2)-y).^2));
            %fprintf('Merging ROIs %d and %d. Corr: %.3f. Old sizes: %d %d. New size: %d. ROI left: %d\n', oldID1, oldID2, R(1,2), numPixels1, numPixels2, length(newROI{it1}.pixels), length(newROI));
            newROI(it2) = [];
            experiment.rawTraces(:, it2) = [];
            done = false;
            fullyDone = false;
            break;
          end
        end
      end
    end
    partIt = partIt + length(newROI)-(it1-1);
    if(params.pbar > 0)
      ncbar.update(2*partIt/(length(newROI)*(length(newROI)-1)));
    end
  end
  experiment.ROI = newROI;
end
if(params.pbar > 0)
  logMsg(sprintf('Number of ROI reduced from: %d to %d', numROI, length(experiment.ROI)));
end
% Recover previous options
if(~isempty(oldExtraction))
  experiment.extractTracesOptionsCurrent = oldExtraction;
else
  experiment = rmfield(experiment, 'extractTracesOptionsCurrent');
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------