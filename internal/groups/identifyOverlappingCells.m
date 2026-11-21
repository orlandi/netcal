function experiment = identifyOverlappingCells(experiment, varargin)
% IDENTIFYOVERLAPPINGCELLS separates overlapping cells
%
% USAGE:
%    experiment = IDENTIFYHCG(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see: identifyOverlappingCellsOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = identifyOverlappingCells(experiment)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also extractTraces

% EXPERIMENT PIPELINE
% name: identify overlapping cells
% parentGroups: fluorescence: group classification
% optionsClass: identifyOverlappingCellsOptions
% requiredFields: traces

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(identifyOverlappingCellsOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Identifying Overlapping Cells');
%--------------------------------------------------------------------------

% Fix in case for some reason the group is a cell
if(iscell(params.group))
  mainGroup = params.group{1};
else
  mainGroup = params.group;
end

members = getAllMembers(experiment, mainGroup);

switch params.tracesType
  case 'smoothed'
    experiment = loadTraces(experiment, 'normal');
    traces = experiment.traces;
  case 'raw'
    experiment = loadTraces(experiment, 'raw');
    traces = experiment.rawTraces;
  case 'denoised'
    experiment = loadTraces(experiment, 'rawTracesDenoised');
    traces = experiment.rawTracesDenoised;
end

currentOrder = members;

correlationDistance = params.correlationLevel;

subTraces = traces(:, currentOrder)';
distmat = squareform(1-pdist(subTraces, 'correlation'));

% ROI coordinates now
ROIcoords = cell2mat(cellfun(@(x)[x.center*params.pixelSize x.plane*params.planeSize], experiment.ROI(currentOrder), 'UniformOutput', false));
ROIdistMat = squareform(pdist(ROIcoords, 'euclidean'));
ROImaxSize = cellfun(@(x)x.maxDistance, experiment.ROI(currentOrder))*params.pixelSize;
%maxSize = max(cellfun(@(x)x.maxDistance, experiment.ROI(currentOrder)));
ROIradiusCheck = ROImaxSize+ROImaxSize';
ROIradiusCheck(find(tril(ones(size(ROIradiusCheck))))) = NaN;
%ROIradiusCheck(find(eye(size(ROIradiusCheck)))) = NaN;
[overlapI, overlapJ] = find(ROIdistMat <= ROIradiusCheck);
realHit = false(size(overlapI));
partialHit = false(size(overlapI));
logMsg(sprintf('Found %d possible overlapping pair candidates (%.2f%% of total)', length(overlapI), length(overlapI)/length(currentOrder)));
for it = 1:length(overlapI)
  pxI = experiment.ROI{currentOrder(overlapI(it))}.pixels;
  pxJ = experiment.ROI{currentOrder(overlapJ(it))}.pixels;
  minPixels = min([length(pxI) length(pxJ)]);
  if(length(intersect(pxI, pxJ))/minPixels >= params.overlapFraction)
    % Now check their correlation
    if(distmat(overlapI(it), overlapJ(it)) >= correlationDistance)
      realHit(it) = true;
    else
      partialHit(it) = true;
    end
  end
end
logMsg(sprintf('Down to %d after pixel-matching (%.2f%% of total)', sum(realHit)+sum(partialHit), (sum(realHit)+sum(partialHit))/length(currentOrder)));
logMsg(sprintf('Down to %d after correlation checks (%.2f%% of total) %d Unique ROI', sum(realHit), sum(realHit)/length(currentOrder), length(unique(union(overlapI(realHit), overlapJ(realHit))))));

% Now iterate until no overlaps exist
ROItoRemove = [];
% Compute the skewness of all traces as a proxy of SNR
sk = skewness(subTraces, [], 3);
overlapItmp = overlapI(realHit);
overlapJtmp = overlapJ(realHit);
while(~isempty(overlapItmp))
  if(sk(overlapItmp(end)) > sk(overlapJtmp(end)))
    invalidIdx = overlapJtmp(end);
  else
    invalidIdx = overlapItmp(end);
  end
  ROItoRemove = [ROItoRemove; currentOrder(invalidIdx)];
  invalidRows = union(find(overlapItmp == invalidIdx), find(overlapJtmp == invalidIdx));
  overlapItmp(invalidRows) = [];
  overlapJtmp(invalidRows) = [];
end
logMsg(sprintf('Have to remove %d ROI', length(ROItoRemove)));

% overlapMatrix = false(size(distmat));
% overlapIdx = find(realHit);
% for it = 1:length(overlapIdx)
%   overlapMatrix(overlapI(overlapIdx(it)), overlapJ(overlapIdx(it))) = true;
% end
% [nComponents,sizes,netMembers] = networkComponents(overlapMatrix);
% validC = find(sizes > 1);
% logMsg(sprintf('Found %d overlapping groups', length(validC)));
% overlapImg = zeros(size(experiment.avgImg, 1), size(experiment.avgImg, 2), 3, 'uint8');
% cmap = rand(length(validC),3);
% %for it = 1:length(validC)
% for it = 1:1
%   cellList = currentOrder(netMembers{validC(it)});
%   %overlapImg = overlapImg+visualizeROI(zeros(size(overlapImg)), experiment.ROI(cellList), 'plot', false, 'color', false, 'mode', 'edge', 'ROIcolorIntensity', it);
%   %overlapImg = overlapImg+visualizeROI(zeros(size(overlapImg)), experiment.ROI(cellList), 'plot', false, 'color', true, 'mode', 'edge', 'Color', repmat(cmap(it, :), [length(cellList) 1]));
%   %overlapImg = imfuse(overlapImg,visualizeROI(zeros(size(experiment.avgImg)), experiment.ROI(cellList), 'plot', false, 'color', true, 'mode', 'edge', 'cmap', repmat(cmap(it, :), [length(cellList) 1])), 'method', 'blend');
%   overlapImg = overlapImg + visualizeROI(zeros(size(experiment.avgImg)), experiment.ROI(cellList), 'plot', false, 'color', true, 'mode', 'edge', 'cmap', repmat(cmap(it, :), [length(cellList) 1]));
% end
% overlapImg = overlapImg + visualizeROI(zeros(size(experiment.avgImg)), experiment.ROI(ROItoRemove), 'plot', false, 'color', true, 'mode', 'edge', 'cmap', repmat([1 1 1], [length(ROItoRemove) 1]));
% ac = ~~max(overlapImg, [], 3);
% figure;
% imshow(experiment.avgImg);
% hold on;
% im = imshow(overlapImg);
% im.AlphaData = ac;

newGroup = setxor(currentOrder, ROItoRemove);

% Validation
logMsg(sprintf('Running overlapping checks again. Outcome should be strictly 0'));
currentOrder = newGroup;

correlationDistance = params.correlationLevel;

subTraces = traces(:, currentOrder)';
distmat = squareform(1-pdist(subTraces, 'correlation'));

% ROI coordinates now
ROIcoords = cell2mat(cellfun(@(x)[x.center*params.pixelSize x.plane*params.planeSize], experiment.ROI(currentOrder), 'UniformOutput', false));
ROIdistMat = squareform(pdist(ROIcoords, 'euclidean'));
ROImaxSize = cellfun(@(x)x.maxDistance, experiment.ROI(currentOrder))*params.pixelSize;
%maxSize = max(cellfun(@(x)x.maxDistance, experiment.ROI(currentOrder)));
ROIradiusCheck = ROImaxSize+ROImaxSize';
ROIradiusCheck(find(tril(ones(size(ROIradiusCheck))))) = NaN;
%ROIradiusCheck(find(eye(size(ROIradiusCheck)))) = NaN;
[overlapI, overlapJ] = find(ROIdistMat <= ROIradiusCheck);
realHit = false(size(overlapI));
partialHit = false(size(overlapI));
logMsg(sprintf('Found %d possible overlapping pair candidates (%.2f%% of total)', length(overlapI), length(overlapI)/length(currentOrder)));
for it = 1:length(overlapI)
  pxI = experiment.ROI{currentOrder(overlapI(it))}.pixels;
  pxJ = experiment.ROI{currentOrder(overlapJ(it))}.pixels;
  minPixels = min([length(pxI) length(pxJ)]);
  if(length(intersect(pxI, pxJ))/minPixels >= params.overlapFraction)
    % Now check their correlation
    if(distmat(overlapI(it), overlapJ(it)) >= correlationDistance)
      realHit(it) = true;
    else
      partialHit(it) = true;
    end
  end
end
logMsg(sprintf('Down to %d after pixel-matching (%.2f%% of total)', sum(realHit)+sum(partialHit), (sum(realHit)+sum(partialHit))/length(currentOrder)));
logMsg(sprintf('Down to %d after correlation checks (%.2f%% of total) %d Unique ROI', sum(realHit), sum(realHit)/length(currentOrder), length(unique(union(overlapI(realHit), overlapJ(realHit))))));

% newOrder
experiment.traceGroups.overlapFix = cell(2, 1);
experiment.traceGroupsNames.overlapFix = cell(2, 1);
experiment.traceGroupsOrder.ROI.overlapFix = cell(2, 1);
experiment.traceGroupsOrder.similarity.overlapFix = cell(2, 1);

for it = 1:2
  switch it
    case 1
      experiment.traceGroups.overlapFix{it} = newGroup;
      experiment.traceGroupsNames.overlapFix{it} = 'valid';
      experiment.traceGroupsOrder.ROI.overlapFix{it} = sort(newGroup);
    case 2
      experiment.traceGroups.overlapFix{it} = ROItoRemove;
      experiment.traceGroupsNames.overlapFix{it} = 'rejected';
      experiment.traceGroupsOrder.ROI.overlapFix{it} = sort(ROItoRemove);
  end
end

logMsg(sprintf('Overlap identification finished for group: %s. Valid: %d. Rejected: %d (%.1f%%)', mainGroup, length(newGroup), length(ROItoRemove), 100*length(newGroup)/length(members)));

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
