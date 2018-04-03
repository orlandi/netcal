function saveROI(experiment, ROI, varargin)
% SAVEROI saves ROI data with all pixel information
%
% USAGE:
%    saveROI(experiment, ROI)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
%    ROI - obtained from loadROI() and refined (or not)
%
% INPUT optional arguments ('key' followed by its value):
%
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
%    'tag' - tag to append to the experiment file. Default:
%    appends '_ROI' to the original HIS file name
%
% EXAMPLE:
%    saveROI(experiment, ROI)
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.tag = '_ROI';
params.verbose = true;
params = parse_pv_pairs(params, varargin);

if(params.verbose)
  logMsgHeader('Saving ROI', 'start');

end

fpa = experiment.folder;
outputfilename = [fpa filesep experiment.name params.tag '.txt'];

if(~isempty(gcbf))
    [fileName, pathName] = uiputfile('*.txt', 'Select filename', [experiment.folder experiment.name params.tag '.txt']);
    if(fileName == 0)
        logMsg('Invalid filename', 'e');
        return;
    else
        outputfilename = [pathName fileName];
    end
end

% Get maximum number of pixels in a ROI
biggestROI = 1;
for i = 1:length(ROI)
    biggestROI = max(biggestROI, length(ROI{i}.pixels));
end

fID = fopen(outputfilename, 'w');
for i = 1:length(ROI)
    pixelList = [ROI{i}.pixels(:); nan(biggestROI-length(ROI{i}.pixels),1)];
    [y,x] = ind2sub([experiment.height, experiment.width], pixelList(:));
    coords = [y;x];
    fprintf(fID, '%d ', ROI{i}.ID, coords);
    fprintf(fID, '\n');
end
fclose(fID);

if(params.verbose)
  logMsgHeader('Done!', 'finish');
end
