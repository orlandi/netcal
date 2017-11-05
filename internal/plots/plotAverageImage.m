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
optionsClass = plotAverageImageOptions;
params = optionsClass().get;
if(length(varargin) >= 1 && isa(varargin{1}, class(optionsClass)))
  params = varargin{1}.get;
  if(length(varargin) > 1)
    varargin = varargin(2:end);
  else
    varargin = [];
  end
end
% Define additional optional argument pairs
params.pbar = [];
params = parse_pv_pairs(params, varargin);

if(experiment.bpp == 8)
  imgData = uint8(experiment.avgImg);
elseif(experiment.bpp == 16)
  imgData = uint16(experiment.avgImg);
else
  imgData = uint16(experiment.avgImg);
end
if(params.showFigure)
  visible = 'on';
else
  visible = 'off';
end
hFig = figure('Name', 'Average fluorescence image autocorrected', 'NumberTitle', 'off', 'Visible', visible);
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
  [minI, maxI] = autoLevelsFIJI(imgData, experiment.bpp);
  caxis([minI maxI]);
end

colormap(params.colormap);
if(params.showColorbar)
  colorbar;
end
title('Average fluorescence image');
set(gca,'XTick',[]);
set(gca,'YTick',[]);

ui = uimenu(hFig, 'Label', 'Export');
uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.pdf';'*.eps'; '*.tiff'; '*.png'}, [experiment.folder experiment.name '_averageImage']});

if(params.saveFigure)
  if(~exist(experiment.folder, 'dir'))
    mkdir(experiment.folder);
  end
  figFolder = [experiment.folder 'figures' filesep];
  if(~exist(figFolder, 'dir'))
    mkdir(figFolder);
  end
  export_fig([figFolder, experiment.name, '_averageImage', params.saveFigureTag, '.', params.saveFigureType], ...
             sprintf('-r%d', params.saveFigureResolution), ...
             sprintf('-q%d', params.saveFigureQuality));
end

if(~params.showFigure)
  close(hFig);
end
