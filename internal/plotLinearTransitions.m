function hFig = plotLinearTransitions(populationsBefore, populationsTransitions, varargin)
% PLOTLINEARTRANSITIONS Plots in a line the transitions between
% different populations
%
% USAGE:
%   plotLinearTransitions(populationsBefore, populationsTransitions)
%
% INPUT arguments:
%   populationsBefore - list of counts in each population
%
%   populationsTransitions - matrix defining where the populations go to,
%   so A(i,j) means the amount that left i and went to j
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: linearTransitionsOptions
%
% OUTPUT arguments:
%   none
%
% EXAMPLE:
%   plotLinearTransitions(populationsBefore, populationsTransitions)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also linarTransitionsOptions

optionsClass = linearTransitionsOptions;
params = optionsClass().get;
if(nargin > 2 && isa(varargin{1}, class(optionsClass)))
  params = varargin{1}.get;
  if(nargin >= 2)
    varargin = varargin(2:end);
  end
end
% Define additional optional argument pairs
params.gui = [];
% Parse them
params = parse_pv_pairs(params, varargin);

% Set parameters
fractionsNames = params.populationsNames;
beforeAfterNames = params.beforeAfterNames;
titleName = params.title;
barPositions = params.barPositions;
barWidth = params.barWidth;
delta = params.populationsGap;
popMinSize = params.barMinSize;

barGap = params.barGap;
radTextGap = params.populationNamesGap;
radTextInnerGap = params.transitionsNamesGap;
sigmoidPrefactor = params.sigmoidPrefactor;
barsBlackEdges = params.barsBlackEdges;
transitionsBlackEdges = params.transitionsBlackEdges;

populationsAfter = sum(populationsTransitions);
if(size(populationsBefore, 1) > 1)
  populationsBefore = populationsBefore';
end
if(size(populationsAfter, 1) > 1)
  populationsAfter = populationsAfter';
end

fractionsBefore = populationsBefore/sum(populationsBefore);
fractionsAfter = populationsAfter/sum(populationsAfter);

fractionTransfers = zeros(length(populationsBefore), length(populationsBefore), 2);
for i = 1:length(populationsBefore)
  for j = 1:length(populationsBefore)
    fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populationsBefore(i), populationsTransitions(i,j)/populationsAfter(j)];
  end
end

N = length(populationsBefore);

Ncols = N*2;
cmap = eval([params.colormap '(Ncols+1)']);
cmap = cmap(2:end, :);
cmap = [cmap(1:2:end, :); cmap(2:2:end, :)];
cmapvals = floor(linspace(1, length(cmap), Ncols));

hFig = figure('units', 'centimeters');
hFig.Position = [hFig.Position(1:2) 30 30];

hold on;
axis equal;
box on;
%
xlim([-0.2 0.2]+barPositions);
ylim([-0.05 1.15]);
set(gca,'XTick',[]);
set(gca,'YTick',[]);

%%plot([0 0], yl,'k--');

% Modified to avoid overlap at 2PI
fractionEdgesBeforeWithDelta = zeros(2, length(fractionsBefore));
fractionEdgesAfterWithDelta = zeros(2, length(fractionsAfter));

alpha = 1-delta*(length(fractionsBefore)-1)-popMinSize*length(fractionsBefore);

for i = 1:length(fractionEdgesBeforeWithDelta)
  if(i ==  1)
    fractionEdgesBeforeWithDelta(1, i) = 0;
    fractionEdgesAfterWithDelta(1, i) = 0;
  else
    fractionEdgesBeforeWithDelta(1, i) = fractionEdgesBeforeWithDelta(2, i-1)+delta;
    fractionEdgesAfterWithDelta(1, i) = fractionEdgesAfterWithDelta(2, i-1)+delta;
  end
  if(i == length(fractionEdgesBeforeWithDelta))
    fractionEdgesBeforeWithDelta(2, i) = 1;
    fractionEdgesAfterWithDelta(2, i) = 1;
  else
    fractionEdgesBeforeWithDelta(2, i) = ...
      fractionEdgesBeforeWithDelta(1, i) + fractionsBefore(i)*alpha+popMinSize;
    fractionEdgesAfterWithDelta(2, i) = ...
      fractionEdgesAfterWithDelta(1, i) + fractionsAfter(i)*alpha+popMinSize;
  end
end

fractionEdgesBefore = mean(fractionEdgesBeforeWithDelta);
fractionEdgesAfter = mean(fractionEdgesAfterWithDelta);

% Create the bars
for i = 1:N
  xPatchBefore = [0 0 -1 -1]*barWidth+barPositions(1);
  yPatchBefore = [fractionEdgesBeforeWithDelta(1,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(1,i)];
  xPatchAfter = [0 0 1 1]*barWidth+barPositions(2);
  yPatchAfter = [fractionEdgesAfterWithDelta(1,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(1,i)];
  P = patch(xPatchBefore, yPatchBefore, 'r');
  set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1, ...
    'edgecolor', cmap(cmapvals(i),:));
  if(barsBlackEdges)
    P.EdgeColor = 'k';
  end
  P = patch(xPatchAfter, yPatchAfter, 'r');
  set(P,'facecolor', cmap(cmapvals(i+N),:),'linewidth',1, ...
    'edgecolor', cmap(cmapvals(i+N),:));
  if(barsBlackEdges)
    P.EdgeColor = 'k';
  end
end

patchSize = [];
patchHandles = [];
% Quick pass to get patchSizes and then do them in order
for i = 1:N
  for j = 1:N
    fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
    fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
    cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
    cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];
  
    f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
    f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
    f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
    f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);
    patchSize = [patchSize; i, j, f2-f1];
  end
end

patchSize = sortrows(patchSize, -3);

for pit = 1:size(patchSize, 1)
  if(patchSize(pit, 3) == 0)
    continue;
  end
  i = patchSize(pit, 1);
  j = patchSize(pit, 2);
  fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
  fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
  cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
  cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

  f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
  f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
  f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
  f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);

  radsBefore = [f1 f2];
  radsAfter = [f3 f4];
  
  xBefore = [1, 1]*barPositions(1)+barGap;
  xAfter = [1, 1]*barPositions(2)-barGap;
  yBefore = [f1 f2];
  yAfter = [f3 f4];
  
  [xLineDown, yLineDown] = getSigmoidConnection([xBefore(1) xAfter(1)], [yBefore(1) yAfter(1)], sigmoidPrefactor);
  [xLineUp, yLineUp] = getSigmoidConnection([xBefore(2) xAfter(2)], [yBefore(2) yAfter(2)], sigmoidPrefactor);
  
  patchX = [xLineDown xLineUp(end:-1:1)];
  patchY = [yLineDown yLineUp(end:-1:1)];
  
  % Now the interpolating line for colors
  [nxI, nyI] = getSigmoidConnection([mean(xBefore) mean(xAfter)], [mean(yBefore) mean(yAfter)], sigmoidPrefactor);
  initialColor = cmap(i, :);
  finalColor = cmap(j+N, :);
  
  cI = zeros(length(nxI), 3);
  for cc = 1:3
    cI(:, cc) = initialColor(cc)+(0:(length(nxI)-1))/(length(nxI)-1)*(finalColor(cc)-initialColor(cc));
  end
  % Now get the associated patch interpolated color
  patchC = zeros(length(patchX), 1, 3);
  closestP = [1:size(cI,1), size(cI,1):-1:1];
  
  patchC(:, 1, :) = cI(closestP, :);
  
  P = patch(patchX', patchY', patchC);
  
  if(transitionsBlackEdges)
    P.EdgeColor = 'k';
  else
    set(P, 'edgecolor', 'none');
  end
  set(P, 'FaceAlpha', params.transparency);
  patchHandles = [patchHandles; P];
end

% Now the texts
% First the titles
text(barPositions(1)-barWidth, 1.05, beforeAfterNames{1}, 'HorizontalAlignment', 'left', ...
  'FontSize', 16, 'FontWeight', 'bold');
text(barPositions(2)+barWidth, 1.05, beforeAfterNames{2}, 'HorizontalAlignment', 'right', ...
  'FontSize', 16, 'FontWeight', 'bold');

text(0, 1.1, titleName, 'HorizontalAlignment', 'center', ...
  'FontSize', 20, 'FontWeight', 'bold');


% Now the populations
textPosBefore = fractionEdgesBefore;
textPosAfter = fractionEdgesAfter;

for i = 1:N
    xt = barPositions(1)-barWidth-radTextGap;
    yt = textPosBefore(i);
    newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsBefore(i))};
    switch params.countType
      case 'relative'
        newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsBefore(i))};
      case 'absolute'
        newName = {fractionsNames{i}; sprintf('%d',populationsBefore(i))};
    end
    a=text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
      'FontSize', 12, 'FontWeight', 'bold');
    xt = barPositions(2)+barWidth+radTextGap;
    yt = textPosAfter(i);
    
    switch params.countType
      case 'relative'
        newName = {fractionsNames{i}; sprintf('%.3g%%',100*fractionsAfter(i))};
      case 'absolute'
        newName = {fractionsNames{i}; sprintf('%d',populationsAfter(i))};
    end
    text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
      'FontSize', 12, 'FontWeight', 'bold');
end

% Now the innerfractions
for pit = 1:size(patchSize, 1)
  if(patchSize(pit, 3) == 0)
    continue;
  end
  i = patchSize(pit, 1);
  j = patchSize(pit, 2);
  fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
  fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
  cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
  cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];

  f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
  f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
  f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
  f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);
 
  xt = barPositions(1)+barGap+radTextInnerGap;
  yt = mean([f1 f2]);  
  switch params.countType
    case 'relative'
      newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 1))};
    case 'absolute'
      newName = {sprintf('%d', populationsTransitions(i, j))};
  end
  a=text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
    'FontSize', 12, 'FontWeight', 'bold');
  xt = barPositions(2)-barGap-radTextInnerGap;
  yt = mean([f3 f4]);
  
  switch params.countType
    case 'relative'
      newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 2))};
    case 'absolute'
      newName = {sprintf('%d', populationsTransitions(i, j))};
  end
  text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
    'FontSize', 12, 'FontWeight', 'bold');
end

axis off;