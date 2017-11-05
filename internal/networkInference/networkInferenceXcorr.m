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
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

% EXPERIMENT PIPELINE
% name: cross-correlation
% parentGroups: network inference
% optionsClass: networkInferenceXcorrOptions
% requiredFields: spikes

obj = networkInferenceBase;
obj.init(networkInferenceXcorrOptions, 'cross-correlation', varargin{:}, 'gui', gcbf);
% Transfomr the lags
obj.params.maximumLag = round(obj.params.maximumLag*experiment.fps);
[success, inferenceData, inferenceDataSurrogates, members] = obj.infer(@infer, experiment, obj.params.value, obj.params.maximumLag, obj.params.normalizationType);
if(success)
  experiment = loadBigFields(experiment, {'inference', 'inferenceSurrogates'});
  if(~isfield(experiment, 'inference') || ~isfield(experiment.inference, 'xcorr'))
    experiment.inference.xcorr = zeros(length(experiment.ROI));
    experiment.inferenceSurrogates.xcorr = zeros(length(experiment.ROI));
  elseif(numel(experiment.inference.xcorr) ~= length(experiment.ROI)^2)
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
obj.cleanup();

  %------------------------------------------------------------------------
  function retData = infer(I, J, value, lag, norm)
    % If I is a matrix it means it has the surrogates incorporated
    if(size(I, 2) > 1)
%       dataOrig = xcorr(I(:, 1), J, lag, norm);
%       data = zeros(length(dataOrig), size(I, 2));
%       data(:, 1) = dataOrig;
%       for i = 2:size(I, 2)
%         data(:, i+1) = xcorr(I(:, i), J, lag, norm);
%       end
      %data = xcorr2(I, J, lag, norm);
      data = xcorr2(I, J); % No lag or norm for now
    else
      data = xcorr(I, J, lag, norm);
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
      end
    end
  end
end