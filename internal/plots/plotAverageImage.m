function experiment = plotAverageImage(experiment, varargin)
% PLOTAVERAGEIMAGE plots the avearge image
%
% USAGE:
%    experiment = plotAverageImage(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    none
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = plotAverageImage(experiment)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: plot average image
% parentGroups: fluorescence: basic: plots
% optionsClass: plotAverageImageOptions
% requiredFields: avgImg, bpp, folder, name

% Pass class options
%--------------------------------------------------------------------------
[params, var] = processFunctionStartup(plotAverageImageOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];
% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Plotting average image');
%--------------------------------------------------------------------------


if(experiment.bpp == 8)
  imgData = uint8(experiment.avgImg);
elseif(experiment.bpp == 16)
  imgData = uint16(experiment.avgImg);
else
  imgData = uint16(experiment.avgImg);
end

% Consistency checks
if(params.saveOptions.onlySaveFigure)
  params.saveOptions.saveFigure = true;
end
if(ischar(params.styleOptions.figureSize))
  params.styleOptions.figureSize = eval(params.styleOptions.figureSize);
elseif(numel(params.styleOptions.figureSize) == 1)
  params.styleOptions.figureSize = [1 1]*params.styleOptions.figureSize;
end

% Create necessary folders
if(params.saveOptions.saveFigure)
  switch params.saveOptions.saveBaseFolder
    case 'experiment'
      baseFolder = experiment.folder;
    case 'project'
      baseFolder = [experiment.folder '..' filesep];
  end
  if(~exist(baseFolder, 'dir'))
    mkdir(baseFolder);
  end
    figFolder = [baseFolder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
end

baseFigName = experiment.name;

if(params.saveOptions.onlySaveFigure)  
  visible = 'off';
else
  visible = 'on';
end

hFig = figure('Name', sprintf('Avg F img autocorrected: %s', experiment.name), 'NumberTitle', 'off', 'Visible', visible, 'Tag', 'netcalPlot');
hFig.Position = setFigurePosition(gcbf, 'width', params.styleOptions.figureSize(1), 'height', params.styleOptions.figureSize(2));

imagesc(imgData);
hold on;
ROIimgData = imagesc(ones(size(imgData)));
valid = zeros(size(imgData));
set(ROIimgData, 'AlphaData', valid);

if(~strcmp(params.showROI, 'none') && isfield(experiment, 'ROI') && ~isempty(experiment.ROI))
  newImg = imgData;
  ROIimg = visualizeROI(zeros(size(newImg)), experiment.ROI, 'plot', false, 'color', true, 'mode', params.showROI);
  nROIimg = bwperim(sum(ROIimg,3) > 0);
  nROIimg = cat(3, nROIimg, nROIimg, nROIimg);
  ROIimg(~nROIimg) = ROIimg(~nROIimg)*0.25;
  ROIimg(nROIimg) = ROIimg(nROIimg)*2;
  ROIimg(ROIimg > 255) = 255;
  invalid = (ROIimg(:,:,1) == 0 & ROIimg(:,:,2) == 0 & ROIimg(:,:,3) == 0);
  alpha = ones(size(ROIimg,1), size(ROIimg,2))*params.ROItransparency;
  alpha(invalid) = 0;
  set(ROIimgData, 'AlphaData', alpha);
  set(ROIimgData, 'CData', ROIimg);
end

axis equal tight;
if(params.rescaleImage)
  [minI, maxI] = autoLevelsFIJI(imgData, experiment.bpp, true);
  caxis([minI maxI]);
end
cmap = eval(params.styleOptions.colormap);
colormap(cmap);
if(params.showColorbar)
  colorbar;
end
title(sprintf('Avg F img: %s', experiment.name), 'interpreter','none');
set(gca,'XTick',[]);
set(gca,'YTick',[]);

ui = uimenu(hFig, 'Label', 'Export');
     uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_raster']});

if(params.saveOptions.saveFigure)
  %[figFolder, baseFigName, '_raster', params.saveFigureTag, '.', params.saveFigureType]
  export_fig([figFolder, baseFigName, '_raster', params.saveOptions.saveFigureTag, '.', params.saveOptions.saveFigureType], ...
              sprintf('-r%d', params.saveOptions.saveFigureResolution), ...
              sprintf('-q%d', params.saveOptions.saveFigureQuality), hFig);
end

if(params.saveOptions.onlySaveFigure)
  close(hFig);
end

% Execute additional figure commands
if(~isempty(params.additionalFigureOptions) && ischar(params.additionalFigureOptions))
  params.additionalFigureOptions = java.io.File(params.additionalFigureOptions);
end
if(~isempty(params.additionalFigureOptions) && params.additionalFigureOptions.isFile)
  run(char(params.additionalFigureOptions.getAbsoluteFile));
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------
