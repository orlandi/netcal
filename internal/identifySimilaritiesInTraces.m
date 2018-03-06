function [orderedTraces, perm, newmat] = identifySimilaritiesInTraces(experiment, traces, varargin)
% IDENTIFYSIMILARITIESINTRACES identify similarities based on correlation
%
% USAGE:
%    TODO
%
% INPUT arguments:
%
%    experiment - structure obtained from loadExperiment()
%
%    traces - obtained from extractTraces() or somewhere else
%
% INPUT optional arguments ('key' followed by its value):
%
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
%   TODO
%
% OUTPUT arguments:
%
%    orderedTraces - the original traces reordered by similarity
%
%    perm - permutation of the original traces, i.e., first entry in perm
%    is the index of the old trace (usually the ROI)
%
%   distmat - correlation matrix (normalized to 0,1), i.e., 0 inv corr

% EXAMPLE:
%    [traces, perm, distmat] = identifySimilaritiesInTraces(traces)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.verbose = true;
params.similarityMatrixTag = '_traceSimilarity_all';
params.saveSimilarityMatrix = true;
params.showSimilarityMatrix = true;
params.cmap = morgenstemning(256);
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, varargin);
params = barStartup(params, 'Identifying similarities', true);
%--------------------------------------------------------------------------

subTraces = traces';
distmat = pdist(subTraces, 'correlation');

Z = linkage(distmat);
fig = figure('visible','off');
[~, ~, perm] = dendrogram(Z,0);
close(fig)
perm = perm';
orderedTraces = traces(:, perm);

% Change the scale of the matrix
newmat = squareform(distmat);
%newmat = max(newmat(:))-newmat(perm,perm);
newmat = (2-newmat(perm,perm))/2;
newmat(find(eye(size(newmat)))) = NaN;

if(~params.showSimilarityMatrix && ~params.saveSimilarityMatrix && ~params.verbose)
  return;
end

if(~params.showSimilarityMatrix)
  hfig = figure('Visible', 'off');
else
  hfig = figure;
end
ax = axes('Parent',hfig);
cmap = params.cmap;
pcolor(ax, newmat);shading flat;
colormap(hfig, cmap);
cb = colorbar(ax, 'location','EastOutside');

xlim(ax, [1 length(newmat)]);
ylim(ax, [1 length(newmat)]);
axis(ax, 'square', 'ij');
box(ax, 'on');
xlabel(ax,'ROI index');
ylabel(ax,'ROI index');
%mtit('trace similarity', 'yoff', 0.2);
title(ax,'traces similarity');

barPosition = get(cb,'position');
barPosition = barPosition + [0.05, 0, 0, 0]; %%%%%%%%
barWidthFactor = 0.4;
barHeightFactor = 1;
barPosition(1) = barPosition(1)+barPosition(3)*(1-barWidthFactor)/2;
barPosition(3) = barPosition(3)*barWidthFactor;
barPosition(4) = barPosition(4)*barHeightFactor;
set(cb,'position',barPosition);

% Export
if(params.saveSimilarityMatrix)
  try
    fpa = [experiment.folder filesep 'figures'];
    if(~exist(fpa, 'dir'))
        mkdir(fpa);
    end
    outputfilename = [experiment.folder filesep 'figures' filesep experiment.name params.similarityMatrixTag '.png'];
    export_fig(hfig, outputfilename, '-nocrop', '-r150');
  catch
    logMsg('Could not export figure', 'w');
  end
end

if(~params.showSimilarityMatrix)
    close(hfig);
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

