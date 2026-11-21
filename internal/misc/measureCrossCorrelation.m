function experiment = measureCrossCorrelation(experiment, varargin)
%% MEASURECROSSCORRELATION: Calculates cross-correlation of spikes using
% MatLab xCorr
%
% USAGE:
%    experiment = measureCrossCorrelation(experiment, subdivisions, normalize)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments:
%    subdivisions - divide video into discrete sections (1 for whole video)
%
% INPUT optional arguments:
%    normalize - whether to use on of MatLabs normalization options
%
% OUTPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% EXAMPLE:
%    experiment = measureCrossCorrelationexperiment)
%
% Copyright (C) 2016-2017, Alexander J. Kipp <ajkipp@ucalgary.ca>, Javier G. Orlandi <javiergorlandi@gmail.com>
%
% 

% EXPERIMENT PIPELINE
% name: measure cross-correlation
% parentGroups: spikes
% optionsClass: measureCrossCorrelationOptions
% requiredFields: spikes
% producedFields: measureCrossCorrelation

%%
%parameters

[params, var] = processFunctionStartup(measureCrossCorrelationOptions, varargin{:});
% Define additional optional argument pairs
params.pbar = [];

% Parse them
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Measuring CrossCorrelations', false);

%%
%%Initialize variables and acquire raster

asdf2 = experimentToAsdf2(experiment);
totalNeurons = 0; 
totalSpikes = 0;
totalFrames = experiment.numFrames;
maxDivisions = params.maxDivisions;

%%
%%Begin sectioning and calculating
 for gridMax = (1:maxDivisions)
    currentCells = asdf2; 
    fullSignal = zeros(totalFrames, 1);
    imageY = (experiment.height)/gridMax;
    incrementY = imageY;
    
    if(~isfield(experiment, 'measureCrossCorrelation'))
        experiment.measureCrossCorrelation = cell(gridMax, 1);
    else
        experiment.measureCrossCorrelation{gridMax} = cell(gridMax);
    end

    for k = (gridMax:-1:1)
        imageX = (experiment.width)/gridMax;
        incrementX = imageX;
        for l = (gridMax:-1:1)
           for c = (1:length(currentCells.raster))
               if (~isnan(currentCells.raster{c})) & (experiment.ROI{c}.center(1) <= (imageX)) & (experiment.ROI{c}.center(2) <= (imageY))
                   totalSpikes = totalSpikes + length(currentCells.raster{c});
                   fullSignal(currentCells.raster{c}) =  fullSignal(currentCells.raster{c}) + 1;
                   currentCells.raster{c} = [];
                   totalNeurons = totalNeurons + 1;
               end 
           end

           quickCrossCorrelogram = xcorr(fullSignal, params.scaleopt);

           switch params.averaging 
               case 'neurons'
                   quickCrossCorrelogram = quickCrossCorrelogram / totalNeurons;
               case 'spikes'
                   quickCrossCorrelogram = quickCrossCorrelogram / totalSpikes;
           end
           
           if totalNeurons ~= 0
               experiment.measureCrossCorrelation{gridMax}{l, k} = struct('crossCorrelogram', quickCrossCorrelogram, 'totalNeurons', totalNeurons, 'totalSpikes', totalSpikes);
           
           else 
               experiment.measureCrossCorrelation{gridMax}{l, k} = NaN;
           end
           
           fullSignal = zeros(totalFrames, 1);
           totalSpikes = 0;
           totalNeurons = 0;
           imageX = imageX + incrementX;
           %logMsg2(sprintf('Measured CrossCorrelation: %3.f', 'y = ', k, 'x = ', l))

        end
        imageY = imageY + incrementY;
    end
 end
 
%% 
%-------------------------------------------------------------------------
barCleanup(params);
%-------------------------------------------------------------------------