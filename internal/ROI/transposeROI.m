function experiment = transposeROI(experiment, varargin)
% transposeROI will transpose the coordinates of all ROI - only useful for
% unintended imports
%
% USAGE:
%    experiment = transposeROI(experiment, varargin)
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
%    experiment = transposeROI(experiment)
%
% Copyright (C) 2016-2015, Javier G. Orlandi <javier.orlandi@ucalgary.ca>

% EXPERIMENT PIPELINE
% name: transpose ROI
% parentGroups: ROI
% requiredFields: ROI, avgImg, folder, name

[params, var] = processFunctionStartup([], varargin{:});
% Define additional optional argument pairs
params.pbar = [];
params.verbose = true;
params = parse_pv_pairs(params, var);
params = barStartup(params, 'Transposing ROI', true);
%-----------------------------------------------x---------------------------

ROI = experiment.ROI;
newROI = ROI;
avgImg = experiment.avgImg;
for idx = 1:length(ROI)
    newImg = zeros(size(avgImg));
    newImg(ROI{idx}.pixels) = 1;
    newImg = newImg';
    newROI{idx}.pixels = find(newImg);
end
experiment.ROI = newROI;

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------

end