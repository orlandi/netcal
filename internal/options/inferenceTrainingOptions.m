classdef inferenceTrainingOptions < baseOptions
% INFERENCETRAININGOPTIONS Default options for inference training
%   Class containing the parameters to check the difference inference algorithms
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also viewInferenceTraining, baseOptions, optionsWindow

  properties
    % Symbol to use for plotting the spikes (only used in training)
    symbol = {'.','-','o','*','x','s','v'};
    
    % Shows the model (infered) trace on top of the original trace (for the methods that create a model trace, peeling and foopsi for now)
    showModelTrace = true;
  end
end
