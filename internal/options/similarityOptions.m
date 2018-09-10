classdef similarityOptions < baseOptions
% SIMILARITYOPTIONS Options for the similarity analysis
%   Class containing the options for similarity analysis
%
%   Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
%
%   See also smothTraces, baseOptions, optionsWindow

  properties
    % Saves the similarity matrix to an external file
    saveSimilarityMatrix = true;

    % Tag to append to the output file name (if saved)
    similarityMatrixTag = '_traceSimilarity_all';
    
    % Shows the similarity matrix in screen
    showSimilarityMatrix = true;

    % Colormap to use in displaying the matrix
    colormap = 'morgenstemning';
  end
end
