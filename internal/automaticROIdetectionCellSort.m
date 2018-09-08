function experiment = automaticROIdetectionCellSort(experiment, varargin)
% AUTOMATICROIDETECTIONCELLSORT automatically detects ROI using CellSort methods
%
% USAGE:
%    experiment = automaticROIdetection(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: ROIautomaticOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = automaticROIdetection(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: automatic ROI detection with CellSort
% parentGroups: fluorescence: cellSort
% optionsClass: ROIautomaticCellSortOptions
% requiredFields: denoisedData
% producedFields: ROI

%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(ROIautomaticCellSortOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them

params = parse_pv_pairs(params, var);
params = barStartup(params, 'Autodetecting ROI using CellSort');
%--------------------------------------------------------------------------

smwidth = params.gaussianSmoothingKernelSize;
thresh = params.spatialTheshold;
arealims = params.minimumSize;
plotting = 0;
experiment = loadTraces(experiment, 'denoisedData', 'pbar', params.pbar);
if(params.pbar > 0)
  ncbar.setCurrentBarName('Autodetecting ROI');
end
fullROI = {};
curID = 0;

for it1 = 1:length(experiment.denoisedData)
  ncbar.setCurrentBarName(sprintf('Autodetecting ROI - block (%d/%d)', it1, length(experiment.denoisedData)));
  % Temporary hack to fix block size on previous denoised data
  experiment.denoisedData(it1).blockSize = experiment.denoisedData(it1).blockCoordinatesLast-experiment.denoisedData(it1).blockCoordinates+1;

  curBlock = experiment.denoisedData(it1);
  Ncomps = size(curBlock.score,2);
  
  spFilters = zeros(curBlock.blockSize(1), curBlock.blockSize(2), curBlock.Ncomponents);
  for it2 = 1:Ncomps
    selComponent = it2;
    sp = mean(curBlock.score(:, selComponent)*curBlock.coeff(:, selComponent)', 1);
    spFilters(:, :, selComponent) = reshape(sp, curBlock.blockSize(1), curBlock.blockSize(2));
  end

  [ica_segments, ~, ~] = CellsortSegmentation(permute(spFilters, [3 1 2]), smwidth, thresh, arealims, plotting);
  newROI = cell(size(ica_segments, 1), 1);
  invalidROI = [];
  for it2 = 1:size(ica_segments, 1)
    if(params.eliminateBorderROIs)
      submask = squeeze(ica_segments(it2, :, :));
      invalid = false;
      % Check Row borders other than the first
      if(curBlock.blockCoordinates(1) > 1)
        invalid = any(submask(1, :));
      end
      % Check Col borders other than the first
      if(~invalid && curBlock.blockCoordinates(2) > 1)
        invalid = any(submask(:, 1));
      end
      % Check Row borders other than the last
      if(~invalid && curBlock.blockCoordinatesLast(1) < size(curBlock.mask, 1))
        invalid = any(submask(end, :));
      end
      % Check Col borders other than the last
      if(~invalid && curBlock.blockCoordinatesLast(2) < size(curBlock.mask, 2))
        invalid = any(submask(:, end));
      end
      if(invalid)
        invalidROI = [invalidROI; it2];
        continue;
      end
    end
    curID = curID + 1;
    newROI{it2}.ID = curID;
    mask = zeros(size(curBlock.mask));
    mask(curBlock.blockCoordinates(1)+(1:curBlock.blockSize(1))-1,...
         curBlock.blockCoordinates(2)+(1:curBlock.blockSize(2))-1) = squeeze(ica_segments(it2, :, :));
    if(curBlock.needsTranspose)
      mask = mask';
    end
    newROI{it2}.pixels = find(mask);
    newROI{it2}.weights = mask(newROI{it2}.pixels);
    [y, x] = ind2sub(size(mask), newROI{it2}.pixels);
    newROI{it2}.center = [mean(x), mean(y)]; % Same as the centroid
    newROI{it2}.maxDistance = max(sqrt((newROI{it2}.center(1)-x).^2+(newROI{it2}.center(2)-y).^2));
    ncbar.setCurrentBarName(sprintf('Autodetecting ROI - block (%d/%d) - IC (%d/%d)', it1, length(experiment.denoisedData), it2, size(ica_segments, 1)));
    ncbar.update(it2/size(ica_segments, 1));
  end
  if(params.eliminateBorderROIs)
    if(~isempty(invalidROI))
      newROI(invalidROI) = [];
    end
  end
  fullROI = [fullROI, newROI{:}];
  if(params.pbar > 0)
    ncbar.update(it1/length(experiment.denoisedData));
  end
end
experiment.ROI = fullROI';


%if(params.verbose || params.pbar > 0)
logMsg(sprintf('%d ROI found', length(experiment.ROI)));
%end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------