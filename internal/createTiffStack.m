function stackFile = createTiffStack(experiment, varargin)
% CREATETIFFSTACK generate a TIFF stack from the HIS
%
% USAGE:
%    stackFile = createTiffStack(experiment, varargin)
%
% INPUT arguments:
%    experiment - structure obtained from loadExperiment()
%
% INPUT optional arguments ('key' followed by its value):
%    'subset' - [initial final]. If not empty, only analyzes the frames
%    between initial and final (in seconds). Default: empty
%
%    'outputfilename' - filename to store the stack at. Default:
%    appends '_stack' to the original HIS file name
%
%    'verbose' - true/false. If true, outputs verbose information. Default:
%    true
%
% OUTPUT arguments:
%    stackFile - link to the file
%
% EXAMPLE:
%    stackFile = createTiffStack(experiment)
%
% Copyright (C) 2016, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.verbose = true;
params.subset = [];
params.outputfilename = '';
params = parse_pv_pairs(params, varargin);


if(params.verbose)
    fprintf('\n----------------------------------\n');
    MSG = 'Creating TIFF stack';
    fprintf([datestr(now, 'HH:MM:SS'), ' ', MSG '\n']);
end


if(~isempty(params.subset))
    tmpFrames = round(params.subset*experiment.fps);
    firstFrame = tmpFrames(1);
    lastFrame = tmpFrames(2);
    if(firstFrame < 1)
        firstFrame = 1;
    end
    if(lastFrame > experiment.numFrames)
        lastFrame = experiment.numFrames;
    end
    fprintf('Subset not empty. Only using frames in the range (%d,%d)\n', firstFrame, lastFrame);
    
else
    firstFrame = 1;
    lastFrame = experiment.numFrames;
end
selectedFrames = firstFrame:lastFrame;

numFrames = length(selectedFrames);

if(isempty(params.outputfilename))
    fpa = experiment.folder;
    [~, fpb, ~] = fileparts(experiment.handle);
    if(~exist(fpa, 'dir'))
        mkdir(fpa);
    end
    outputfilename = [fpa filesep fpb '_stack.tif'];
else
    outputfilename = params.outputfilename;
end


if(params.verbose)
    textprogressbar('Creating the stack: ');
end

for i = 1:length(selectedFrames)
    %currentFrame = double(getFrame(experiment, selectedFrames(i)-1));
    currentFrame = getFrame(experiment, selectedFrames(i));
    if(i == 1)
        imwrite(currentFrame, outputfilename, 'compression', 'lzw');
    else
        imwrite(currentFrame, outputfilename, 'writemode', 'append', 'compression', 'lzw');
    end
    if(params.verbose)
        if(mod(i,floor(numFrames/100)) == 0)
            textprogressbar(round(i/numFrames*100));
        end
    end
end


if(params.verbose)
    textprogressbar('Done!');
end


if(params.verbose)
    MSG = 'Stack finished';
    fprintf([datestr(now, 'HH:MM:SS'), ' ', MSG '\n']);
    fprintf('----------------------------------\n');
end

