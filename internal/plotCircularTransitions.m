function hFig = plotCircularTransitions(populationsBefore, populationsTransitions, varargin)
% PLOTCIRCULARTRANSITIONS Plots in a circle the transitions between
% different populations
%
% USAGE:
%   plotCircularTransitions(populationsBefore, populationsTransitions)
%
% INPUT arguments:
%   populationsBefore - list of counts in each population
%
%   populationsTransitions - matrix defining where the populations go to,
%   so A(i,j) means the amount that left i and went to j
%
% INPUT optional arguments ('key' followed by its value):
%
%    see: circularTransitionsOptions
%
% OUTPUT arguments:
%   none
%
% EXAMPLE:
%   plotCircularTransitions(populationsBefore, populationsTransitions)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% See also circularTransitionsOptions

optionsClass = circularTransitionsOptions;
optionsClass = optionsClass.setDefaults();
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

% First hack
populationsAfter = sum(populationsTransitions);
if(size(populationsBefore, 1) > 1)
  populationsBefore = populationsBefore';
end
if(size(populationsAfter, 1) > 1)
  populationsAfter = populationsAfter';
end
populations = [populationsBefore populationsAfter(end:-1:1)];
N = length(populations);

% Set parameters
fractionsNames = params.populationsNames;
beforeAfterNames = params.beforeAfterNames;
titleName = params.title;
rad1 = params.innerRadius;
rad2 = params.outerRadius;
delta = params.populationsGap;
rad3 = params.transitionRadius;
expn = params.curvatureExponent;
maxF = params.curvatureMultiplier;
radText = params.populationNamesPosition;
radTextInner = params.transitionFractionsTextPosition;
barsBlackEdges = params.barsBlackEdges;
transitionsBlackEdges = params.transitionsBlackEdges;
curvatureType = params.curvatureType;
popMinSize = params.barMinSize;
    
cmap = eval([params.colormap '(N+1)']);
cmap = cmap(2:end, :);

% Hack to duplicate the stuff
fractionsNames = [fractionsNames, fractionsNames(end:-1:1)];  
populationsTransitions = [zeros(size(populationsTransitions)), populationsTransitions(:,end:-1:1);
  zeros(size(populationsTransitions)), zeros(size(populationsTransitions))];
fractionHack = 2;
cmap = [cmap(1:2:end, :); cmap(end:-2:2, :)];

% Now no more hack - generalized
fractions = populations/sum(populations);

fractionTransfers = zeros(length(populations), length(populations), 2);
for i = 1:length(populations)
  for j = 1:length(populations)
    fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populations(i), populationsTransitions(i,j)/populations(j)];
  end
end

cmapvals = floor(linspace(1, length(cmap), N));

hFig = figure('units', 'centimeters');
hFig.Position = [hFig.Position(1:2) 20 20];

hold on;
axis square;
box on;
%
xlim([-1.2 1.2]);
ylim([-1.2 1.2]);
set(gca,'XTick',[]);
set(gca,'YTick',[]);
yl = ylim;
plot([0 0], yl,'k--');

initialAngle = -pi/2;
% Modified to avoid overlap at 2PI
fractionEdges = [0, cumsum(fractions)];

fractionsBefore = populationsBefore/sum(populationsBefore);
fractionsAfter = populationsAfter/sum(populationsAfter);
fractionEdgesWithDelta = zeros(2, length(fractionsBefore)+length(fractionsAfter));


alpha = 1-delta*(length(fractions))-popMinSize*length(fractions);

for i = 1:length(fractionEdgesWithDelta)
  if(i ==  1)
    fractionEdgesWithDelta(1, i) = delta/2;
  else
    fractionEdgesWithDelta(1, i) = fractionEdgesWithDelta(2, i-1)+delta;
  end
  if(i == length(fractionEdgesWithDelta))
    fractionEdgesWithDelta(2, i) = 1-delta/2;
  else
    fractionEdgesWithDelta(2, i) = ...
      fractionEdgesWithDelta(1, i) + fractions(i)*alpha+popMinSize;
  end
end

fractionEdges = mean(fractionEdgesWithDelta);

angles = -fractionEdgesWithDelta*2*pi + initialAngle;


% Ok, get the new angles
rads = zeros(N, 2);
for i = 1:N
      rads(i, 1) = angles(1, i);
      rads(i, 2) = angles(2, i);
end

% Calculate the segmentet circle
for i = 1:N
  P = plot_arc(rads(i,1),rads(i,2),0,0,rad1,rad2,100);
  %set(P,'facecolor',cmap(cmapvals(i),:),'linewidth',1, 'edgecolor','k');
  set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1);
  if(barsBlackEdges)
    set(P, 'edgecolor', 'k');
  else
    set(P, 'edgecolor', cmap(cmapvals(i),:));
  end
end

patchSize = [];
patchHandles = [];
% Quick pass to get patchSizes and then do them in order
fractionSizes = diff(fractionEdgesWithDelta);
for i = 1:N
  for j = 1:N
    cumsumFractionsBefore = [cumsum(fractionTransfers(i, :, 1),'reverse') 0];
    cumsumFractionsAfter = [cumsum(fractionTransfers(:, j, 2),'reverse')' 0];
  
    f1 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j);
    f2 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j+1);
    f3 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i);
    f4 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i+1);
    patchSize = [patchSize; i, j, f2-f1];
  end
end

patchSize = sortrows(patchSize, 3);

for pit = 1:size(patchSize, 1)
  i = patchSize(pit, 1);
  j = patchSize(pit, 2);
  if(patchSize(pit, 3) == 0)
    continue;
  end
  cumsumFractionsBefore = [cumsum(fractionTransfers(i, :, 1),'reverse') 0];
  cumsumFractionsAfter = [cumsum(fractionTransfers(:, j, 2),'reverse')' 0];

  f1 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j);
  f2 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j+1);
  f3 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i);
  f4 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i+1);
  
  radsBefore = -[f1 f2]*2*pi + initialAngle;
  radsAfter = -[f3 f4]*2*pi + initialAngle;
  
  a = radsBefore(1);
  b = radsBefore(2);
  h = 0;
  k = 0;
  l = 100;
  t = linspace(a,b,l);
  x1 = rad3*cos(t) + h;
  y1 = rad3*sin(t) + k;

  a = radsAfter(1);
  b = radsAfter(2);
  h = 0;
  k = 0;
  l = 100;
  t = linspace(a,b,l);
  x2 = rad3*cos(t) + h;
  y2 = rad3*sin(t) + k;
  
  % Change curvature depending on x position
  switch curvatureType
    case 'custom'
      prefactor1 = maxF*(1-mean(abs([x1(1) x2(1)]))).^expn;
      prefactor2 = maxF*(1-mean(abs([x1(end) x2(end)]))).^expn;
      prefactor3 = maxF*(1-mean(abs([x1(1) x1(end) x2(1) x2(end)]))).^expn;
    case 'tangent'
      prefactor1 = maxF;
      prefactor2 = maxF;
      prefactor3 = maxF;
  end
  
  [nx1, ny1] = getCurvedConnection([x1(end) x2(1)], [y1(end) y2(1)], prefactor1, curvatureType);
  [nx2, ny2] = getCurvedConnection([x2(end) x1(1)], [y2(end) y1(1)], prefactor2, curvatureType);
  % Now try the patch
  patchX = [x1, nx1, x2, nx2];
  patchY = [y1, ny1, y2, ny2];

  % Now the interpolating line for colors
  [nxI, nyI] = getCurvedConnection([x1(round(length(x1)/2)) x2(round(length(x2)/2))], [y1(round(length(y1)/2)) y2(round(length(y2)/2))], prefactor3, curvatureType);
  initialColor = cmap(i, :);
  finalColor = cmap(j, :);
  cI = zeros(length(nxI), 3);
  for cc = 1:3
    cI(:, cc) = initialColor(cc)+(0:(length(nxI)-1))/(length(nxI)-1)*(finalColor(cc)-initialColor(cc));
  end
  % Now get the associated patch interpolated color
  patchC = zeros(length(patchX), 1, 3);

  closestP = [ones(size(x1)), 1:size(cI,1), ones(size(x1))*size(cI,1), size(cI,1):-1:1];
  patchC(:, 1, :) = cI(closestP, :);
  P = patch(patchX', patchY', patchC);
  if(transitionsBlackEdges)
    set(P, 'edgecolor', 'k', 'FaceAlpha', params.transparency); %0.75
  else
    set(P, 'edgecolor', 'none', 'FaceAlpha', params.transparency);
  end
  patchHandles = [patchHandles; P];
end

% Now the texts

% First the titles
text(-1.2, 1.1, beforeAfterNames{1}, 'HorizontalAlignment', 'left', ...
  'FontSize', 16, 'FontWeight', 'bold');
text(1.2, 1.1, beforeAfterNames{2}, 'HorizontalAlignment', 'right', ...
  'FontSize', 16, 'FontWeight', 'bold');

text(0, 1.3, titleName, 'HorizontalAlignment', 'center', ...
  'FontSize', 20, 'FontWeight', 'bold');

% Now the populations
textPos = fractionEdges;
%textPos = fractionEdges(1:end-1)+diff(fractionEdges)/2;
textAngles = -textPos*2*pi + initialAngle;
%textPosBefore = fractionEdgesBefore;
%textPosAfter = fractionEdgesAfter;


for i = 1:N
    xt = radText*cos(textAngles(i));
    yt = radText*sin(textAngles(i));
    switch params.countType
      case 'relative'
        newName = {fractionsNames{i}; sprintf('%.3g%%',fractionHack*100*fractions(i))};
      case 'absolute'
        newName = {fractionsNames{i}; sprintf('%d',populations(i))};
    end
    if(xt > 0)
      angleAdd = 0;
      angleAlign = 'left';
    else
      angleAdd = 180;
      angleAlign = 'right';
    end
    a=text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
      'FontWeight', 'bold', 'rotation', textAngles(i)/2/pi*360+angleAdd);
end

% Now the innerfractions
fractionSizes = diff(fractionEdgesWithDelta);
for pit = 1:size(patchSize, 1)
  i = patchSize(pit, 1);
  j = patchSize(pit, 2);
  if(patchSize(pit, 3) == 0)
    continue;
  end
  cumsumFractionsBefore = [cumsum(fractionTransfers(i, :, 1), 'reverse') 0];
  cumsumFractionsAfter = [cumsum(fractionTransfers(:, j, 2), 'reverse')' 0];

  f1 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j);
  f2 = fractionEdgesWithDelta(1, i)+fractionSizes(i)*cumsumFractionsBefore(j+1);
  f3 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i);
  f4 = fractionEdgesWithDelta(1, j)+fractionSizes(j)*cumsumFractionsAfter(i+1);
 
  radsBefore = -mean([f1 f2])*2*pi + initialAngle;
  radsAfter = -mean([f3 f4])*2*pi + initialAngle;

  xt = radTextInner*cos(radsBefore);
  yt = radTextInner*sin(radsBefore);
  if(xt > 0)
      angleAdd = 0;
      angleAlign = 'right';
    else
      angleAdd = 180;
      angleAlign = 'left';
  end
  switch params.countType
    case 'relative'
      newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 1))};
    case 'absolute'
      newName = {sprintf('%d', populationsTransitions(i, j))};
  end
  
  rotationAngle = radsBefore/2/pi*360+angleAdd;
  if(isnan(rotationAngle))
    rotationAngle = 0;
  end
  a=text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
    'FontWeight', 'bold', 'rotation', rotationAngle);
  
  xt = radTextInner*cos(radsAfter);
  yt = radTextInner*sin(radsAfter);
  if(xt > 0)
      angleAdd = 0;
      angleAlign = 'right';
    else
      angleAdd = 180;
      angleAlign = 'left';
  end
  switch params.countType
    case 'relative'
      newName = {sprintf('%.3g%%', 100*fractionTransfers(i, j, 2))};
    case 'absolute'
      newName = {sprintf('%d', populationsTransitions(i, j))};
  end
  
  rotationAngle = radsAfter/2/pi*360+angleAdd;
  if(isnan(rotationAngle))
    rotationAngle = 0;
  end
  text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
    'FontWeight', 'bold', 'rotation', rotationAngle);
end

axis off;
