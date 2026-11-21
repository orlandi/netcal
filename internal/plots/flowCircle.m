%% Poluation flow circle

populationsBefore = [300 500 200];
populationsTransitions = [150 15 135 ; % Neuron to stuff
  350 100 50; % Glia to stuff
  100 20 80]; % Noise to stuff
populationsAfter = sum(populationsTransitions);

fractionsBefore = populationsBefore/sum(populationsBefore);
fractionsAfter = populationsAfter/sum(populationsAfter);

fractionsNames = {'neuron', 'glia', 'noise'};
beforeAfterNames = {'basal', 'bicuculine'};
titleName = 'WT';

fractionTransfers = zeros(length(populationsBefore), length(populationsBefore), 2);
for i = 1:length(populationsBefore)
  for j = 1:length(populationsBefore)
    fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populationsBefore(i), populationsTransitions(i,j)/populationsAfter(j)];
  end
end

rad1 = 0.95;
rad2 = rad1+0.1;
delta = 20e-3;
rad3 = rad1-0.025;
%$preFractor = 0.85;
expn = 0.5;
maxF = 0.9;
radText = rad2+0.05;
radTextInner = rad3-0.025;
N = length(populationsBefore)*2;
network.X = 1:N;
network.Y = 1:N;

Ncols = N/2;
cmap = parula(N+1);
cmap = cmap(2:end, :);
cmap = [cmap(1:2:end, :); cmap(2:2:end, :)];

cmapvals = floor(linspace(1, length(cmap), N));

createFigure(11.5*2,11.5*2);
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
fractionEdgesBefore = [0, cumsum(fractionsBefore)];
fractionEdgesAfter = [0, cumsum(fractionsAfter)];

fractionEdgesBeforeWithDelta = [fractionEdgesBefore(1:end-1)+delta; fractionEdgesBefore(2:end)-delta];
fractionEdgesAfterWithDelta = [fractionEdgesAfter(1:end-1)+delta; fractionEdgesAfter(2:end)-delta];

anglesBefore = -fractionEdgesBeforeWithDelta*pi + initialAngle;
anglesAfter = fractionEdgesAfterWithDelta*pi + initialAngle;

% Ok, get the new angles
rads = zeros(N, 2);
for i = 1:N
    if(i <= N/2)
      rads(i, 1) = anglesBefore(1, i);
      rads(i, 2) = anglesBefore(2, i);
    else
      rads(i, 1) = anglesAfter(1, i-N/2);
      rads(i, 2) = anglesAfter(2, i-N/2);
    end
end



% Calculate the segmentet circle
for i = 1:N
    P = plot_arc(rads(i,1),rads(i,2),0,0,rad1,rad2,100);
    %set(P,'facecolor',cmap(cmapvals(i),:),'linewidth',1, 'edgecolor','k');
    set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1, 'edgecolor', cmap(cmapvals(i),:));
    
end

patchSize = [];
patchHandles = [];
% Quick pass to get patchSizes and then do them in order
for i = 1:N/2
  for j = 1:N/2
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
  i = patchSize(pit, 1);
  j = patchSize(pit, 2);
  fractionSizesBefore = diff(fractionEdgesBeforeWithDelta);
  fractionSizesAfter = diff(fractionEdgesAfterWithDelta);
  cumsumFractionsBefore = [0 cumsum(fractionTransfers(i, :, 1))];
  cumsumFractionsAfter = [0 cumsum(fractionTransfers(:, j, 2))'];
  %cumsumFractionsBefore = [0 cumsum(fractionsBefore)];
  %cumsumFractionsAfter = [0 cumsum(fractionsAfter)];

  f1 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j);
  f2 = fractionEdgesBeforeWithDelta(1, i)+fractionSizesBefore(i)*cumsumFractionsBefore(j+1);
  f3 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i);
  f4 = fractionEdgesAfterWithDelta(1, j)+fractionSizesAfter(j)*cumsumFractionsAfter(i+1);

  radsBefore = -[f1 f2]*pi + initialAngle;
  radsAfter = [f3 f4]*pi + initialAngle;

  a = radsBefore(1);
  b = radsBefore(2);
  h = 0;
  k = 0;
  l = 100;
  t = linspace(a,b,l);
  x1 = rad3*cos(t) + h;
  y1 = rad3*sin(t) + k;
  %plot(x1, y1, 'Color', cmap(i, :));

  a = radsAfter(1);
  b = radsAfter(2);
  h = 0;
  k = 0;
  l = 100;
  t = linspace(a,b,l);
  x2 = rad3*cos(t) + h;
  y2 = rad3*sin(t) + k;
  
  % Change curvature depending on x position
  preFractor1 = maxF*(1-mean(abs([x1(1) x2(1)]))).^expn;
  preFractor2 = maxF*(1-mean(abs([x1(end) x2(end)]))).^expn;
  preFractor3 = maxF*(1-mean(abs([x1(1) x1(end) x2(1) x2(end)]))).^expn;
  
  [nx1, ny1] = getCurvedConnection([x1(1) x2(1)], [y1(1) y2(1)], preFractor1);
  [nx2, ny2] = getCurvedConnection([x1(end) x2(end)], [y1(end) y2(end)], preFractor2);
  
  % Now try the patch
  patchX = [x1, nx2, x2(end:-1:1), nx1(end:-1:1)];
  patchY = [y1, ny2, y2(end:-1:1), ny1(end:-1:1)];
  % Now the interpolating line for colors
  [nxI, nyI] = getCurvedConnection([x1(round(length(x1)/2)) x2(round(length(x2)/2))], [y1(round(length(y1)/2)) y2(round(length(y2)/2))], preFractor3);
  initialColor = cmap(i, :);
  finalColor = cmap(j+N/2, :);
  cI = zeros(length(nxI), 3);
  for cc = 1:3
    cI(:, cc) = initialColor(cc)+(0:(length(nxI)-1))/(length(nxI)-1)*(finalColor(cc)-initialColor(cc));
  end
  % Now get the associated patch interpolated color
  patchC = zeros(length(patchX), 1, 3);
%   for it = 1:length(patchX)
%     curX = patchX(it);
%     curY = patchY(it);
%     [~, closestP] = min((nxI-curX).^2+(nyI-curY).^2);
%     patchC(it, 1, :) = cI(closestP, :);
%   end
  closestP = [ones(size(x1)), 1:size(cI,1), ones(size(x1))*size(cI,1), size(cI,1):-1:1];
  patchC(:, 1, :) = cI(closestP, :);
  P = patch(patchX', patchY', patchC);
  set(P, 'edgecolor', 'none');
  patchHandles = [patchHandles; P];
  %plot(nxI, nyI, 'k');
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
textPosBefore = fractionEdgesBefore(1:end-1)+diff(fractionEdgesBefore)/2;
textPosAfter = fractionEdgesAfter(1:end-1)+diff(fractionEdgesAfter)/2;

textAnglesBefore = -textPosBefore*pi + initialAngle;
textAnglesAfter = textPosAfter*pi + initialAngle;


for i = 1:N/2
    xt = radText*cos(textAnglesBefore(i));
    yt = radText*sin(textAnglesBefore(i));
    newName = {fractionsNames{i}; sprintf('%.0f%%',100*fractionsBefore(i))};
    %newName = {[fractionsNames{i} sprintf(' (%.0f%%)',100*fractionsBefore(i))]};
    a=text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
      'FontWeight', 'bold', 'rotation', textAnglesBefore(i)/2/pi*360+180);
    xt = radText*cos(textAnglesAfter(i));
    yt = radText*sin(textAnglesAfter(i));
    newName = {fractionsNames{i}; sprintf('%.0f%%',100*fractionsAfter(i))};
    text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
      'FontWeight', 'bold', 'rotation', textAnglesAfter(i)/2/pi*360);
end

% Now the innerfractions
for pit = 1:size(patchSize, 1)
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
 
  radsBefore = -mean([f1 f2])*pi + initialAngle;
  radsAfter = mean([f3 f4])*pi + initialAngle;
  
  xt = radTextInner*cos(radsBefore);
  yt = radTextInner*sin(radsBefore);
  newName = {sprintf('%.0f%%',100*fractionTransfers(i, j, 1))};
  %newName = {[fractionsNames{i} sprintf(' (%.0f%%)',100*fractionsBefore(i))]};
  a=text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
    'FontWeight', 'bold', 'rotation', radsBefore/2/pi*360+180);
  xt = radTextInner*cos(radsAfter);
  yt = radTextInner*sin(radsAfter);
  newName = {sprintf('%.0f%%',100*fractionTransfers(i, j, 2))};
  text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
    'FontWeight', 'bold', 'rotation', radsAfter/2/pi*360);
end


%
axis off;

%%

fileName = 'figflow';
%opts = struct('FontMode','scaled','FontSizeMin', 2, 'FontSizeMax', 6, 'LineMode','scaled','Resolution',600);
opts = struct('FontMode','scaled', 'FontSize', 1, 'FontSizeMin', 2, 'LineMode','scaled','Resolution',600);
%opts = struct('FontMode','fixed', 'LineMode','scaled','Resolution',600);
exportfig(gcf,fileName,opts,'format','png','Color','rgb','Bounds','loose');close all;

%system(sprintf('epspdf %s.eps %s.pdf',fileName, fileName),'-echo');


%% Now we can generalize to arbitrary stuff
fractionsNames = {'neuron', 'glia', 'noise'};
beforeAfterNames = {'basal', 'bicuculine'};
titleName = 'WT';
rad1 = 0.95;
rad2 = rad1+0.1;
delta = 10e-3;
rad3 = rad1-0.025;
expn = 0.4;
maxF = 0.8;
radText = rad2+0.05;
radTextInner = rad3-0.025;

populationsBefore = [300 500 200];
populationsTransitions = [150 15 135 ; % Neuron to stuff
  350 100 50; % Glia to stuff
  100 20 80]; % Noise to stuff

% Hack to duplicate the stuff
populationsAfter = sum(populationsTransitions);
populations = [populationsBefore populationsAfter(end:-1:1)];
populationsTransitions = [zeros(size(populationsTransitions)), populationsTransitions(:,end:-1:1);
  zeros(size(populationsTransitions)), zeros(size(populationsTransitions))];

% Now no more hack - generalized
fractions = populations/sum(populations);
fractionsNames = [fractionsNames, fractionsNames(end:-1:1)];

fractionTransfers = zeros(length(populations), length(populations), 2);
for i = 1:length(populations)
  for j = 1:length(populations)
    fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populations(i), populationsTransitions(i,j)/populations(j)];
  end
end

N = length(populations);
network.X = 1:N;
network.Y = 1:N;

cmap = isolum(N+1);
cmap = cmap(2:end, :);
% Also hack the colormap
cmap = [cmap(1:2:end, :); cmap(end:-2:2, :)];

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

fractionEdgesWithDelta = [fractionEdges(1:end-1)+delta; fractionEdges(2:end)-delta];

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
    set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1, 'edgecolor', cmap(cmapvals(i),:));
    
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
  preFractor1 = maxF*(1-mean(abs([x1(1) x2(1)]))).^expn;
  preFractor2 = maxF*(1-mean(abs([x1(end) x2(end)]))).^expn;
  preFractor3 = maxF*(1-mean(abs([x1(1) x1(end) x2(1) x2(end)]))).^expn;
  
  [nx1, ny1] = getCurvedConnection([x1(end) x2(1)], [y1(end) y2(1)], preFractor1);
  [nx2, ny2] = getCurvedConnection([x2(end) x1(1)], [y2(end) y1(1)], preFractor2);
  % Now try the patch
  patchX = [x1, nx1, x2, nx2];
  patchY = [y1, ny1, y2, ny2];

  % Now the interpolating line for colors
  [nxI, nyI] = getCurvedConnection([x1(round(length(x1)/2)) x2(round(length(x2)/2))], [y1(round(length(y1)/2)) y2(round(length(y2)/2))], preFractor3);
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
  set(P, 'edgecolor', 'none', 'FaceAlpha', 0.75);
  patchHandles = [patchHandles; P];
end
alpha = 0.5;

% Now the texts

% First the titles
text(-1.2, 1.1, beforeAfterNames{1}, 'HorizontalAlignment', 'left', ...
  'FontSize', 16, 'FontWeight', 'bold');
text(1.2, 1.1, beforeAfterNames{2}, 'HorizontalAlignment', 'right', ...
  'FontSize', 16, 'FontWeight', 'bold');

text(0, 1.3, titleName, 'HorizontalAlignment', 'center', ...
  'FontSize', 20, 'FontWeight', 'bold');

% Now the populations
textPos = fractionEdges(1:end-1)+diff(fractionEdges)/2;
textAngles = -textPos*2*pi + initialAngle;

for i = 1:N
    xt = radText*cos(textAngles(i));
    yt = radText*sin(textAngles(i));
    % Hack so the fractions are correct
    newName = {fractionsNames{i}; sprintf('%.0f%%',2*100*fractions(i))};
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
  newName = {sprintf('%.0f%%',100*fractionTransfers(i, j, 1))};
  
  a=text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
    'FontWeight', 'bold', 'rotation', radsBefore/2/pi*360+angleAdd);
  
  xt = radTextInner*cos(radsAfter);
  yt = radTextInner*sin(radsAfter);
  if(xt > 0)
      angleAdd = 0;
      angleAlign = 'right';
    else
      angleAdd = 180;
      angleAlign = 'left';
  end
  newName = {sprintf('%.0f%%',100*fractionTransfers(i, j, 2))};
  text(xt, yt, newName, 'HorizontalAlignment', angleAlign, ...
    'FontWeight', 'bold', 'rotation', radsAfter/2/pi*360+angleAdd);
end

axis off;
%%

fileName = 'figflowfinal';
%opts = struct('FontMode','scaled','FontSizeMin', 2, 'FontSizeMax', 6, 'LineMode','scaled','Resolution',600);
opts = struct('FontMode','scaled', 'FontSize', 1, 'FontSizeMin', 2, 'LineMode','scaled','Resolution',600);
%opts = struct('FontMode','fixed', 'LineMode','scaled','Resolution',600);
exportfig(gcf,fileName,opts,'format','png','Color','rgb','Bounds','loose');close all;

%system(sprintf('epspdf %s.eps %s.pdf',fileName, fileName),'-echo');


%% Now for the lines


populationsBefore = [300 500 200];
populationsTransitions = [150 15 135 ; % Neuron to stuff
  350 100 50; % Glia to stuff
  100 20 80]; % Noise to stuff
populationsAfter = sum(populationsTransitions);

fractionsBefore = populationsBefore/sum(populationsBefore);
fractionsAfter = populationsAfter/sum(populationsAfter);

fractionsNames = {'neuron', 'glia', 'noise'};
beforeAfterNames = {'basal', 'bicuculine'};
titleName = 'WT';

fractionTransfers = zeros(length(populationsBefore), length(populationsBefore), 2);
for i = 1:length(populationsBefore)
  for j = 1:length(populationsBefore)
    fractionTransfers(i,j, :) = [populationsTransitions(i,j)/populationsBefore(i), populationsTransitions(i,j)/populationsAfter(j)];
  end
end

barPositions = [-1 1]*0.5;
barWidth = 0.1;

delta = 20e-3;
barGap = 0.015;
radTextGap = 0.01;
radTextInnerGap = 0.01;
sigmoidPrefactor = 0.75;
blackEdges = false;
N = length(populationsBefore);

Ncols = N*2;
%cmap = parula(Ncols+1);
cmap = isolum(Ncols+1);
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
yl = ylim;
%%plot([0 0], yl,'k--');

% Modified to avoid overlap at 2PI
fractionEdgesBefore = [0, cumsum(fractionsBefore)];
fractionEdgesAfter = [0, cumsum(fractionsAfter)];

fractionEdgesBeforeWithDelta = [fractionEdgesBefore(1:end-1)+delta; fractionEdgesBefore(2:end)-delta];
fractionEdgesAfterWithDelta = [fractionEdgesAfter(1:end-1)+delta; fractionEdgesAfter(2:end)-delta];

% Create the bars
for i = 1:N
  xPatchBefore = [0 0 -1 -1]*barWidth+barPositions(1);
  yPatchBefore = [fractionEdgesBeforeWithDelta(1,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(2,i) fractionEdgesBeforeWithDelta(1,i)];
  xPatchAfter = [0 0 1 1]*barWidth+barPositions(2);
  yPatchAfter = [fractionEdgesAfterWithDelta(1,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(2,i) fractionEdgesAfterWithDelta(1,i)];
  P = patch(xPatchBefore, yPatchBefore, 'r');
  set(P,'facecolor', cmap(cmapvals(i),:),'linewidth',1, ...
    'edgecolor', cmap(cmapvals(i),:));
  if(blackEdges)
    P.EdgeColor = 'k';
  end
  P = patch(xPatchAfter, yPatchAfter, 'r');
  set(P,'facecolor', cmap(cmapvals(i+N),:),'linewidth',1, ...
    'edgecolor', cmap(cmapvals(i+N),:));
  if(blackEdges)
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
  
  if(blackEdges)
    P.EdgeColor = 'k';
  else
    set(P, 'edgecolor', 'none');
  end
  set(P, 'edgecolor', 'none', 'FaceAlpha', 0.75);
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
textPosBefore = fractionEdgesBefore(1:end-1)+diff(fractionEdgesBefore)/2;
textPosAfter = fractionEdgesAfter(1:end-1)+diff(fractionEdgesAfter)/2;

for i = 1:N
    xt = barPositions(1)-barWidth-radTextGap;
    yt = textPosBefore(i);
    newName = {fractionsNames{i}; sprintf('%.0f%%',100*fractionsBefore(i))};
    %newName = {[fractionsNames{i} sprintf(' (%.0f%%)',100*fractionsBefore(i))]};
    a=text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
      'FontSize', 12, 'FontWeight', 'bold');
    xt = barPositions(2)+barWidth+radTextGap;
    yt = textPosAfter(i);
    newName = {fractionsNames{i}; sprintf('%.0f%%',100*fractionsAfter(i))};
    text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
      'FontSize', 12, 'FontWeight', 'bold');
end

% Now the innerfractions
for pit = 1:size(patchSize, 1)

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
  newName = {sprintf('%.0f%%',100*fractionTransfers(i, j, 1))};
  %newName = {[fractionsNames{i} sprintf(' (%.0f%%)',100*fractionsBefore(i))]};
  a=text(xt, yt, newName, 'HorizontalAlignment', 'left', ...
    'FontSize', 12, 'FontWeight', 'bold');
  xt = barPositions(2)-barGap-radTextInnerGap;
  yt = mean([f3 f4]);
  newName = {sprintf('%.0f%%',100*fractionTransfers(i, j, 2))};
  text(xt, yt, newName, 'HorizontalAlignment', 'right', ...
    'FontSize', 12, 'FontWeight', 'bold');
end

axis off;
%%

fileName = 'figflowSquarefinal';
%opts = struct('FontMode','scaled','FontSizeMin', 2, 'FontSizeMax', 6, 'LineMode','scaled','Resolution',600);
opts = struct('FontMode','scaled', 'FontSize', 1, 'FontSizeMin', 2, 'LineMode','scaled','Resolution',600);
%opts = struct('FontMode','fixed', 'LineMode','scaled','Resolution',600);
exportfig(gcf,fileName,opts,'format','png','Color','rgb','Bounds','loose');close all;
