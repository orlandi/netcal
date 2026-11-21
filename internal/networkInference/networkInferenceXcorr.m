function experiment = networkInferenceXcorr(experiment, varargin)
% networkInferenceXcorr computes network inference using cross-correlation
%
% USAGE:
%    experiment = networkInferenceXcorr(experiment, varargin)
%
% INPUT arguments:
%    experiment - experiment structure
%
% INPUT optional arguments ('key' followed by its value):
%    see networkInferenceXcorrOptions
%
% OUTPUT arguments:
%    experiment - experiment structure
%
% EXAMPLE:
%    experiment = networkInferenceXcorr(experiment)
%
% Copyright (C) 2016-2026, Javier G. Orlandi <javier.orlandi@ucalgary.ca>

% EXPERIMENT PIPELINE
% name: cross-correlation inference
% parentGroups: network: inference
% optionsClass: networkInferenceXcorrOptions
% requiredFields: ROI

obj = networkInferenceBase;
obj.init(networkInferenceXcorrOptions, 'cross-correlation', varargin{:}, 'gui', gcbf);

% Transfomr the lags
obj.params.maximumLag = round(obj.params.maximumLag*experiment.fps);
[success, inferenceData, inferenceDataSurrogates, members] = obj.infer(@infer, @normalize, experiment, obj.params.value, obj.params.maximumLag, obj.params.normalizationType);
if(success)
  if(strcmp(obj.params.value, 'lag'))
    inferenceData = inferenceData/experiment.fps;
  end
  experiment = loadBigFields(experiment, {'inference', 'inferenceSurrogates'});
  switch obj.params.value
    case 'max'
      if(~isfield(experiment, 'inference') || ~isfield(experiment.inference, 'xcorrMax'))
        experiment.inference.xcorrMax = zeros(length(experiment.ROI));
      end
      if(~isfield(experiment, 'inferenceSurrogates') || ~isfield(experiment.inferenceSurrogates, 'xcorrMax'))
        experiment.inferenceSurrogates.xcorrMax = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inference.xcorrMax) ~= length(experiment.ROI)^2)
        experiment.inference.xcorrMax = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inferenceSurrogates.xcorrMax) ~= length(experiment.ROI)^2*obj.params.surrogates.amount)
        experiment.inferenceSurrogates.xcorrMax = zeros(length(experiment.ROI), length(experiment.ROI), obj.params.surrogates.amount);
      end
      experiment.inference.xcorrMax(members, members) = inferenceData;
      if(size(inferenceDataSurrogates, 3) > 1)
        experiment.inferenceSurrogates.xcorrMax(members, members, :) = inferenceDataSurrogates;
      else
        experiment.inferenceSurrogates.xcorrMax(members, members) = inferenceDataSurrogates;
      end
    case '0lag'
      if(~isfield(experiment, 'inference') || ~isfield(experiment.inference, 'xcorr'))
        experiment.inference.xcorr = zeros(length(experiment.ROI));
      end
      if(~isfield(experiment, 'inferenceSurrogates') || ~isfield(experiment.inferenceSurrogates, 'xcorr'))
        experiment.inferenceSurrogates.xcorr = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inference.xcorr) ~= length(experiment.ROI)^2)
        experiment.inference.xcorr = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inferenceSurrogates.xcorr) ~= length(experiment.ROI)^2*obj.params.surrogates.amount)
        experiment.inferenceSurrogates.xcorr = zeros(length(experiment.ROI), length(experiment.ROI), obj.params.surrogates.amount);
      end
      experiment.inference.xcorr(members, members) = inferenceData;
      if(size(inferenceDataSurrogates, 3) > 1)
        experiment.inferenceSurrogates.xcorr(members, members, :) = inferenceDataSurrogates;
      else
        experiment.inferenceSurrogates.xcorr(members, members) = inferenceDataSurrogates;
      end
    case 'lag'
      if(~isfield(experiment, 'inference') || ~isfield(experiment.inference, 'xcorrLag'))
        experiment.inference.xcorrLag = zeros(length(experiment.ROI));
      end
      if(~isfield(experiment, 'inferenceSurrogates') || ~isfield(experiment.inferenceSurrogates, 'xcorrLag'))
        experiment.inferenceSurrogates.xcorrLag = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inference.xcorrLag) ~= length(experiment.ROI)^2)
        experiment.inference.xcorrLag = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inferenceSurrogates.xcorrLag) ~= length(experiment.ROI)^2*obj.params.surrogates.amount)
        experiment.inferenceSurrogates.xcorrLag = zeros(length(experiment.ROI), length(experiment.ROI), obj.params.surrogates.amount);
      end
      experiment.inference.xcorrLag(members, members) = inferenceData;
      if(size(inferenceDataSurrogates, 3) > 1)
        experiment.inferenceSurrogates.xcorrLag(members, members, :) = inferenceDataSurrogates;
      else
        experiment.inferenceSurrogates.xcorrLag(members, members) = inferenceDataSurrogates;
      end
    otherwise
      if(~isfield(experiment, 'inference') || ~isfield(experiment.inference, 'xcorr'))
        experiment.inference.xcorr = zeros(length(experiment.ROI));
      end
      if(~isfield(experiment, 'inferenceSurrogates') || ~isfield(experiment.inferenceSurrogates, 'xcorr'))
        experiment.inferenceSurrogates.xcorr = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inference.xcorr) ~= length(experiment.ROI)^2)
        experiment.inference.xcorr = zeros(length(experiment.ROI));
      end
      if(numel(experiment.inferenceSurrogates.xcorr) ~= length(experiment.ROI)^2*obj.params.surrogates.amount)
        experiment.inferenceSurrogates.xcorr = zeros(length(experiment.ROI), length(experiment.ROI), obj.params.surrogates.amount);
      end
      experiment.inference.xcorr(members, members) = inferenceData;
      if(size(inferenceDataSurrogates, 3) > 1)
        experiment.inferenceSurrogates.xcorr(members, members, :) = inferenceDataSurrogates;
      else
        experiment.inferenceSurrogates.xcorr(members, members) = inferenceDataSurrogates;
      end
  end
end
experiment.saveBigFields = true;
obj.cleanup();

  %------------------------------------------------------------------------
  function retData = infer(I, J, G, value, lag, type)
    % Multiply by the global signal. If it's 0, those values will not count
    I = bsxfun(@times,I,G);
    J = bsxfun(@times,J,G);
    normalizedData = normalize([I, J], [], [], type);
    I = normalizedData(:, 1:end-1);
    J = normalizedData(:, end);

    if(isempty(lag))
      lag = size(I,1)-1;
    end
    
    % If I is a matrix it means it has the surrogates incorporated
    if(size(I, 2) > 1)
      data = xcorr2(I, J); % No lag for now (normalization has been done outside)
      % Now the lag
      data = data((size(I, 1))-lag:(size(I, 1)+lag), :);
    else
      data = xcorr(I, J, lag);
    end
    retData = zeros(size(I, 2), 1);
    for i = 1:size(I, 2)
      switch value
        case 'max'
          retData(i) = max(data(:, i));
        case 'maxPositive'
          % First values are the negatives, that means I before J
          retData(i) = max(data(1:(floor(length(data)/2)+1), i));
        case '0lag'
          retData(i) = data(floor(length(data)/2)+1, i);
        case 'lag'
          [~, retData(i)] = max(data(:, i));
          center = floor(size(data,1)/2)+1;
          retData(i) = retData(i) - center;

      end
    end
  end
%------------------------------------------------------------------------
  function normalizedData = normalize(data, ~, ~, type)
    switch type
      case 'coeff'
        normalizedData = zeros(size(data));
        for i = 1:size(normalizedData, 2)
          d = data(:, i);
          d = d - mean(d);
          if(sum(d.^2) ~= 0)
            normalizedData(:, i) = d/sqrt(sum(d.^2));
          else
            normalizedData(:, i) = zeros(size(d));
          end
        end
      case 'none'
        normalizedData = data;
    end
  end
end