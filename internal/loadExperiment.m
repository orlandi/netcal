function experiment = loadExperiment(varargin)
% LOADEXPERIMENT loads a movie file associated to a given experiment. Currently supports HIS, DCIMG, AVI, TIF, EXP, MAT filetypes
%
% USAGE:
%    experiment = loadExperiment(filename)
%
% INPUT arguments:
%    filename - HIS file. If empty, it will open the open file dialog box
%
% INPUT optional arguments ('key' followed by its value): 
%    'verbose' - true/false. If true, outputs verbose information
%
%    'project' - project structure (will be used to update folder and save
%    file (only if its an .exp file)
%
% OUTPUT arguments:
%    experiment - structure containing the experiment parameters
%
% EXAMPLE:
%     experiment = loadExperiment(filename)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>

params.verbose = true;
params.project = [];
params.loadTraces = [];
params.pbar = [];
params.filterIndex = [];
params.defaultFolder = [];
experiment = [];

formatsList = {'*.HIS;*.DCIMG;*.AVI;*.BIN;*.BTF;*.MJ2', 'All Movie files (*.HIS, *.DCIMG, *.AVI, *.BIN, *.BTF, *.MJ2)';...
               '*.HIS', 'Hamamatsu HIS files (*.HIS)';...
               '*.DCIMG', 'Hamamatsu DCIMG files (*.DCIMG)'; ...
               '*.AVI', 'AVI files (*.AVI)';...
               '*.BTF', 'Big TIFF files (*.BTF)';...
               '*.TIF,*.TIFF', 'TIF sequence/multitif (*.TIF,*.TIFF)';...
               '*.EXP', 'NETCAL experiment (*.EXP)'; ...
               '*.BIN', 'NETCAL binary experiment (*.BIN)'; ...
               '*.MAT', 'quick_dev (*.MAT)'; ...
               '*.MAT', 'CRCNS datasets (*.MAT)'; ...
               '*.MAT', 'RIKEN (*.MAT)'; ...
               '*.MJ2', 'Motion JPEG 2000'};
filterIndex = [];
if(~isempty(params.filterIndex))
  filterIndex = params.filterIndex;
end
if(mod(length(varargin), 2) == 1)
    fileName = varargin{1};
    if(length(varargin) > 1)
        varargin = varargin(2:end);
    else
        varargin = [];
    end
    params = parse_pv_pairs(params, varargin);
else
    params = parse_pv_pairs(params, varargin);
    if(isempty(gcbf))
        [fileName, pathName, filterIndex] = uigetfile(formatsList,'Select file');
    else
        project = getappdata(gcbf, 'project');
        if(~isempty(params.defaultFolder))
            [fileName, pathName, filterIndex] = uigetfile(formatsList,'Select file', params.defaultFolder);
        elseif(~isempty(project))
          [fileName, pathName, filterIndex] = uigetfile(formatsList,'Select file', project.folder);
        else
          [fileName, pathName, filterIndex] = uigetfile(formatsList,'Select file');
        end
    end
    fileName = [pathName fileName];
    if(~fileName | ~exist(fileName, 'file')) %#ok<BDSCI,OR2,BDLGI>
        return;
    end
end
if(~params.verbose)
  params.pbar = 0;
end
params = barStartup(params, 'Loading experiment', true);

% IF it's an exp file and not a HIS, directly load the structure
[fpa, fpb, fpc] = fileparts(fileName);
switch lower(fpc)
  case '.exp'
    experiment = load(fileName, '-mat');
    % update the experiment name in case it does not coincide with the .exp
    % file
    if(~strcmp(fpb, experiment.name))
      logMsg(sprintf('Experiment name changed from %s to %s', experiment.name, fpb));
    end
    experiment.name = fpb;
    oldFolder = experiment.folder;
%     params.project
%     oldFolder
    try
      if(isfield(params, 'project') && isfield(params.project, 'folder') && ~strcmpi(oldFolder, [params.project.folder experiment.name filesep]))
        [status, msg, msgID] = copyfile(oldFolder, [params.project.folder experiment.name filesep], 'f');
      
      if(status == 0)
        [tfpa tfpb tfpc] = fileparts(fileName);
%         [tfpa filesep '..' filesep experiment.name]
%         [params.project.folder experiment.name filesep]
        [status, msg, msgID] = copyfile([tfpa filesep '..' filesep experiment.name], [params.project.folder experiment.name filesep], 'f');
%         status
%         msg
%         msgID
      end
      end
    catch ME
      logMsg(strrep(getReport(ME),  sprintf('\n'), '<br/>'), 'e');
    end
    if(~isempty(params.project))
      experiment.folder = [params.project.folder experiment.name filesep];
      experiment.saveFile = ['..' filesep 'projectFiles' filesep experiment.name '.exp'];
    end
     % Temporary hack to reduce memory usage, since the baseline is never used
    if(isfield(experiment, 'baseLine'))
      if(isfield(experiment, 'smoothTracesOptionsCurrent') && isprop(experiment.smoothTracesOptionsCurrent, 'storeBaseline') && experiment.smoothTracesOptionsCurrent.storeBaseline == true)
        % Do nothing
      else
        experiment = rmfield(experiment, 'baseLine');
      end
    end
    % Temporary hack to delete the classifier from older versions
    if(isfield(experiment, 'classifier'))
        experiment = rmfield(experiment, 'classifier');
    end
    % Temporary hack to delete old and way too big ML spike options class
    try
      if(isfield(experiment, 'MLspikeParams'))
        if(size(experiment.MLspikeParams, 1) == size(experiment.MLspikeParams, 2))
          experiment = rmfield(experiment, 'MLspikeParams');
        end
      end
    catch
    end
    % Fix groups structures
    experiment = checkGroups(experiment);
    if(~isempty(params.loadTraces))
      experiment = loadTraces(experiment, params.loadTraces);
    end
  case {'.tif', '.tiff'}
    % Allowed syntax for multiple TIFs should be '*_?.tif'
    %regstr = '_\d*.tif(f?)$';
    regstr = '_\d*$';
    if(regexp(fpb, regstr))
      lastPosition = regexp(fpb, regstr);
      baseName = fpb(1:lastPosition);
      fileList = dir([fpa filesep baseName '*.tif*']);
      numFiles = length(fileList);
      experiment.handle = [fpa filesep baseName '1' fpc];
      experiment.folder = [fpa filesep];
      experiment.name = baseName(1:end-1);

      experiment.metadata = '';
      experiment.numFrames = numFiles;

      answer = inputdlg('Enter the video framerate',...
                    'Framerate', [1 60], {'20'});
      if(isempty(answer))
          logMsg('Invalid frame rate', 'e');
          barCleanup(params);
          return;
      end
      frameRate = str2double(strtrim(answer{1}));
      experiment.fps = frameRate;

      experiment.totalTime = experiment.numFrames/experiment.fps;
      fileInfo = imfinfo(experiment.handle);

      experiment.width = fileInfo.Width;
      experiment.height = fileInfo.Height;
      experiment.pixelType = '';
      experiment.bpp = fileInfo.BitsPerSample;
      experiment.saveFile = [experiment.name '.exp'];
    else
      %logMsg('Invalid filename format. It should be: name_d.tif (where d is a number starting at 1)', 'e');
      logMsg('Could not find any sequence. Assuming it''s a multitif file', 'w');
      experiment.handle = fileName;
      experiment.folder = [fpa filesep];
      experiment.name = fpb;
      finfo = imfinfo(fileName);
      metadata_str = finfo(1).ImageDescription;
      metadata_separated = strsplit(metadata_str,';');
      metadata = [];
      for i = 1:length(metadata_separated)
          tmpStr = strsplit(metadata_separated{i},'=');
          if(length(tmpStr) == 2)
              if(isempty(strfind(tmpStr{1},'@')))
                  metadata.(tmpStr{1}) = tmpStr{2};
              end
          end
      end
      experiment.metadata = metadata;
      experiment.numFrames = length(finfo);
      experiment.width = finfo(1).Width;
      experiment.height = finfo(1).Height;
      if(finfo(1).BitDepth == 88)
        pixelType = '*uint8';
        bitsPerPixel = 8;
      elseif(finfo(1).BitDepth == 16)
        pixelType = '*uint16';
        bitsPerPixel = 16;
      elseif(finfo(1).BitDepth == 32)
        pixelType = '*uint32';
        bitsPerPixel = 32;
      end

      experiment.pixelType = pixelType;
      experiment.bpp = bitsPerPixel;
      if(~isempty(metadata) && isfield(metadata, 'vExpTim1'))
        experiment.fps = 1/str2double(metadata.vExpTim1);
      else
        answer = inputdlg('Enter the video framerate',...
                      'Framerate', [1 60], {'20'});
        if(isempty(answer))
            logMsg('Invalid frame rate', 'e');
            barCleanup(params);
            return;
        end
        frameRate = str2double(strtrim(answer{1}));
        experiment.fps = frameRate;
      end

      experiment.totalTime = experiment.numFrames/experiment.fps;
      experiment.saveFile = [experiment.name '.exp'];

    end
    %regexp('D35 Control_0_32.tifa', '_\d*.tif(f?)$')
  case '.dcimg'
    experiment.handle = fileName;
    experiment.folder = [fpa filesep];
    experiment.name = fpb;
    fid = fopen(fileName, 'r');

    fseek(fid, 0, 'bof');
    hdr_bytes = fread(fid, 232);

    bytes_to_skip = 4*fromBytes(hdr_bytes(9:12));
    curr_index = 8 + 1 + bytes_to_skip;

    % Number of frames
    nFrames = fromBytes(hdr_bytes(curr_index:(curr_index+3)));

    curr_index = 48 + 1;
    fileSize = fromBytes(hdr_bytes(curr_index:curr_index+7));

    % bytes per pixel
    curr_index = 156 + 1;
    bitDepth = 8*fromBytes(hdr_bytes(curr_index:curr_index+3));

    % footer location 
    %curr_index = 120 + 1;
    %footerLoc = fromBytes(hdr_bytes(curr_index:curr_index+7));
    % funny entry pair which references footer location - This one
    curr_index = 192 + 1;
    odd = fromBytes(hdr_bytes(curr_index:curr_index+7));

    curr_index = 40 + 1;
    offset = fromBytes(hdr_bytes(curr_index:curr_index+7));
    footerLoc = odd+offset;


    % number of columns (x-size)
    curr_index = 164 + 1;
    xsize_req = fromBytes(hdr_bytes(curr_index:curr_index+3));

    % bytes per row
    curr_index = 168 + 1;
    bytes_per_row = fromBytes(hdr_bytes(curr_index:curr_index+3));
    %if we requested an image of nx by ny pixels, then DCIMG files
    %for the ORCA flash 4.0 still save the full array in x.
    xsize = bytes_per_row/2;

    % binning
    % this only works because MOSCAM always reads out 2048 pixels per row
    % at least when connected via cameralink. This would fail on USB3 connection
    % and probably for other cameras.
    % TODO: find another way to work out binning
    binning = (4096/bytes_per_row);


    % number of rows
    curr_index = 172 + 1;
    ysize = fromBytes(hdr_bytes(curr_index:curr_index+3));

    % TODO: what about ystart? 

    % bytes per image
    curr_index = 176 + 1;
    frameSize = fromBytes(hdr_bytes(curr_index:curr_index+3));

    % Now the weird part to get the frame rate
    fseek(fid, footerLoc+272+nFrames*4, 'bof');
    val = zeros(nFrames, 1);
    % Get all time stamps
    for i = 1:nFrames
        a = fread(fid, 4);
        b = fread(fid, 4);
        val(i) = decodeFloat(a, b);
    end

    % Much easier
    fps = 1/((val(end)-val(1))/nFrames);

    if(bitDepth == 16)
        pixelType = '*uint16';
    elseif(bitDepth == 8)
        pixelType = '*uint8';
    elseif(bitDepth == 32)
        pixelType = '*uint32';
    else
      pixelType = '*uint8';
    end

    experiment.metadata = 'no metadata for .dcimg';
    experiment.numFrames = nFrames;
    experiment.fps = fps;
    experiment.totalTime = experiment.numFrames/experiment.fps;
    experiment.width = xsize_req;
    experiment.height = ysize;
    experiment.pixelType = pixelType;
    experiment.bpp = bitDepth;
    experiment.frameSize = frameSize;
    experiment.binning = binning;
    experiment.saveFile = [experiment.name '.exp'];
    fclose(fid);
  case '.avi'
    experiment.handle = fileName;
    experiment.folder = [fpa filesep];
    experiment.name = fpb;
    obj = VideoReader(fileName);
    %obj.BitsPerPixel
    experiment.bpp = obj.BitsPerPixel;
    if(obj.BitsPerPixel == 16)
        pixelType = '*uint16';
    elseif(obj.BitsPerPixel == 8)
        pixelType = '*uint8';
    elseif(obj.BitsPerPixel == 32)
        pixelType = '*uint32';
    elseif(obj.BitsPerPixel == 24)
        pixelType = '*uint8';
        experiment.bpp = 8;
    end

    experiment.metadata = 'no metadata for .avi';
    experiment.numFrames = round(obj.Duration*obj.FrameRate);
    experiment.fps = obj.FrameRate;
    experiment.totalTime = obj.Duration;
    experiment.width = obj.Width;
    experiment.height = obj.Height;
    experiment.pixelType = pixelType;
    experiment.saveFile = [experiment.name '.exp'];
  case '.mj2'
    experiment.handle = fileName;
    experiment.folder = [fpa filesep];
    experiment.name = fpb;
    obj = VideoReader(fileName);
    experiment.bpp = obj.BitsPerPixel;
    if(obj.BitsPerPixel == 16)
        pixelType = '*uint16';
    elseif(obj.BitsPerPixel == 8)
        pixelType = '*uint8';
    elseif(obj.BitsPerPixel == 32)
        pixelType = '*uint32';
    elseif(obj.BitsPerPixel == 24)
        pixelType = '*uint8';
        experiment.bpp = 8;
    end
    experiment.metadata = 'no metadata for .mj2';
    experiment.numFrames = round(obj.Duration*obj.FrameRate);
    experiment.fps = obj.FrameRate;
    experiment.totalTime = obj.Duration;
    experiment.width = obj.Width;
    experiment.height = obj.Height;
    experiment.pixelType = pixelType;
    experiment.saveFile = [experiment.name '.exp'];
  case '.bin'
    experiment.handle = fileName;
    experiment.folder = [fpa filesep];
    experiment.name = fpb;
    jsonFile = [experiment.folder experiment.name '.json'];
    jsonData = loadjson(jsonFile);
    jsonFields = {'handle', 'metadata', 'numFrames', 'fps', 'totalTime', 'width', 'height', 'pixelType', 'bpp', 'frameSize', 'name'};
    for it = 1:length(jsonFields)
      if(isfield(jsonData, jsonFields{it}))
        experiment.(jsonFields{it}) = jsonData.(jsonFields{it});
      end
    end
    experiment.saveFile = [experiment.name '.exp'];

    %fid = fopen(fileName, 'r');
  case '.btf'
    experiment.handle = fileName;
    experiment.folder = [fpa filesep];
    experiment.name = fpb;
    finfo = imfinfo(fileName);
    metadata_str = finfo(1).ImageDescription;
    metadata_separated = strsplit(metadata_str,';');
    metadata = [];
    for i = 1:length(metadata_separated)
        tmpStr = strsplit(metadata_separated{i},'=');
        if(length(tmpStr) == 2)
            if(isempty(strfind(tmpStr{1},'@')))
                metadata.(tmpStr{1}) = tmpStr{2};
            end
        end
    end
    experiment.metadata = metadata;
    experiment.numFrames = length(finfo);
    experiment.width = finfo(1).Width;
    experiment.height = finfo(1).Height;
    if(finfo(1).BitDepth == 8)
      pixelType = '*uint8';
      bitsPerPixel = 8;
    elseif(finfo(1).BitDepth == 16)
      pixelType = '*uint16';
      bitsPerPixel = 16;
    elseif(finfo(1).BitDepth == 32)
      pixelType = '*uint32';
      bitsPerPixel = 32;
    end
    
    experiment.pixelType = pixelType;
    experiment.bpp = bitsPerPixel;
    if(~isempty(metadata) && isfield(metadata, 'vExpTim1'))
      experiment.fps = 1/str2double(metadata.vExpTim1);
    else
      answer = inputdlg('Enter the video framerate',...
                    'Framerate', [1 60], {'20'});
      if(isempty(answer))
          logMsg('Invalid frame rate', 'e');
          barCleanup(params);
          return;
      end
      frameRate = str2double(strtrim(answer{1}));
      experiment.fps = frameRate;
    end
    
    experiment.totalTime = experiment.numFrames/experiment.fps;
    experiment.saveFile = [experiment.name '.exp'];
  case '.his'
    experiment.handle = fileName;
    experiment.folder = [fpa filesep];
    experiment.name = fpb;

    fid = fopen(fileName, 'r');

    % Get the number of series
    skip = fread(fid, 14);
    nSeries = fread(fid, 1, 'uint32');

    fseek(fid, 0, 'bof');

    % Read the first batch
    fread(fid, 2, 'uint8=>char');
    comentBytes = fread(fid, 1, 'short');
    sizeX = fread(fid, 1, 'short');
    sizeY = fread(fid, 1, 'short');
    fread(fid, 4);
    dataType = fread(fid, 1, 'short');
    if(dataType == 1)
        pixelType = '*uint8';
        bitsPerPixel = 8;
    elseif(dataType == 2)
        pixelType = '*uint16';
        bitsPerPixel = 16;
    else
       pixelType = '*uint16';
       bitsPerPixel = 16;
    end
    %logMsg(['HIS datatype: ' num2str(dataType)], 'e');
    fread(fid, 50);
    metadata_str = fread(fid, comentBytes, 'uint8=>char')';
    metadata_separated = strsplit(metadata_str,';');
    metadata = [];
    for i = 1:length(metadata_separated)
        tmpStr = strsplit(metadata_separated{i},'=');
        if(length(tmpStr) == 2)
            if(isempty(strfind(tmpStr{1},'@')))
                metadata.(tmpStr{1}) = tmpStr{2};
            end
        end
    end
    fclose(fid);
    experiment.metadata = metadata;
    experiment.numFrames = nSeries;
    experiment.width = sizeX;
    experiment.height = sizeY;
    experiment.pixelType = pixelType;
    experiment.bpp = bitsPerPixel;
    experiment.fps = 1/str2double(metadata.vExpTim1);
    if(experiment.numFrames == 0)
      logMsg('Found 0 frames. HIS file might be corrupt. Trying to recover it', 'r');
      experiment.numFrames = 1000000; % 1 million -anybody is going to record more than 1 million frames? Probably not
      [experiment, success] = precacheHISframes(experiment, 'mode', 'fast', 'force', true);
      if(~success)
        experiment.numFrames = 0;
        logMsg('Could not recover the file', 'r');
      else
        logMsg(sprintf('Succesfully recovered HIS file. %d frames found', experiment.numFrames));
      end
    end
    experiment.totalTime = experiment.numFrames/experiment.fps;
    experiment.saveFile = [experiment.name '.exp'];
  case '.mat'
    % Try to guess type of mat file
    if(isempty(filterIndex))
      testMat = load(fileName, '-mat');
      if(isfield(testMat, 'RUN'))
        filterIndex = 8;
      elseif(isfield(testMat, 'data') && isfield(testMat.data, 'expsys'))
        filterIndex = 9;
      else
        logMsg('Could not determine type of MAT file');
        barCleanup(params);
        return;
      end
    end
    if(filterIndex == 8)
      % Import fernando's code
      quick_dev = load(fileName, '-mat');

      if(isfield(quick_dev.RUN, 'orgName'))
        experiment.name = quick_dev.RUN.orgName;
      else
        %[nfpa, nfpb, nfpc] = fileparts(quick_dev.RUN.vidname);
        [nfpa, nfpb, nfpc] = fileparts(fileName);
        experiment.name = nfpb;
      end
      experiment.numFrames = quick_dev.RUN.n_frames;
      experiment.metadata = 'Imported from quick_dev';
      experiment.width = quick_dev.RUN.frame_size(2);
      experiment.height = quick_dev.RUN.frame_size(1);
      experiment.fps = quick_dev.RUN.fps;
      if(isfield(quick_dev.RUN, 'bitDepth'))
        experiment.bpp = quick_dev.RUN.bitDepth;
      else
        experiment.bpp = 8; % Default
      end
      experiment.pixelType = ['*uint' num2str(experiment.bpp)];
      if(isfield(quick_dev.data, 'mean_frame'))
        experiment.avgImg = quick_dev.data.mean_frame;
      else
        experiment.avgImg = zeros(experiment.height, experiment.width);
      end
      experiment.rawTraces = quick_dev.data.trace';
      experiment.traces = experiment.rawTraces;
      experiment.rawT = (0:(experiment.numFrames-1))/experiment.fps;
      experiment.t = experiment.rawT;
      experiment.avgTrace = quick_dev.data.average_trace';
      experiment.avgTraceT = experiment.t;
      experiment.ROI = cell(length(quick_dev.data.cells), 1);
      experiment.totalTime = experiment.t(end);
      if(isfield(quick_dev.RUN,'frameSize'))
        experiment.frameSize = quick_dev.RUN.experiment.frameSize;
      else
        experiment.frameSize = experiment.width*experiment.height*16/4; % HACK
      end
      % Convert ROIs
      for i = 1:length(quick_dev.data.cells)
          experiment.ROI{i}.ID = i;
          experiment.ROI{i}.pixels = quick_dev.data.cells(i).mask;
          experiment.ROI{i}.center = quick_dev.data.cells(i).center;
          experiment.ROI{i}.maxDistance = [];
      end

      experiment.spikes = quick_dev.data.peak_locations;
      % Transform spikes from frames to real times
      for i = 1:length(experiment.spikes)
          experiment.spikes{i} = experiment.spikes{i}/experiment.fps;
      end

      experiment.handle = quick_dev.RUN.vidname;

      experiment.folder = [fpa filesep];
      experiment.saveFile = [experiment.name '.exp'];
    elseif(filterIndex == 9)
      % CRCNS datasets
      crcns = load(fileName, '-mat');
      crcns = crcns.data;
      experiment.name = crcns.recordingID;
      experiment.dt = 0.05; % Fake (20 fps)
      experiment.numFrames = crcns.nbins*crcns.binsize*1e-3/experiment.dt;
      %experiment.dt = crcns.binsize*1e-3; % Since the data is in ms
      experiment.metadata = crcns.expsys;
      experiment.width = 64; % Fake For the electrodes
      experiment.height = 64; % Fake For the electrodes
      experiment.fps = 1/experiment.dt;
      experiment.bpp = 16; % Fake
      experiment.pixelType = '*uint16';
      experiment.rawT = (0:(experiment.numFrames-1))/experiment.fps;
      experiment.t = experiment.rawT;
      experiment.totalTime = experiment.t(end);
      experiment.ROI = cell(length(crcns.channel), 1);
      for it = 1:length(crcns.channel)
        experiment.ROI{it}.ID = num2str(it);
        experiment.ROI{it}.channel = num2str(crcns.channel(it));
      end
      experiment.spikes = cellfun(@(x) x*1e-3*crcns.binsize, crcns.spikes, 'UniformOutput', false);

      experiment.handle = fileName;
      experiment.folder = [fpa filesep];
      experiment.saveFile = [experiment.name '.exp'];
    end
  if(filterIndex == 10)
      riken = load(fileName, '-mat');
      [nfpa, nfpb, nfpc] = fileparts(fileName);
      experiment.name = nfpb;
      experiment.metadata = 'RIKEN';
      experiment.width = size(riken.VDAQ.alldata{1},2);
      experiment.height = size(riken.VDAQ.alldata{1},1);
      experiment.numFrames = size(riken.VDAQ.alldata{1},3);
      experiment.fps = riken.VDAQ.FrameRate(1);
      experiment.bpp = 16;
      experiment.pixelType = ['*uint' num2str(experiment.bpp)];
      experiment.frameSize = experiment.width*experiment.height*16;
      experiment.totalTime = experiment.numFrames/experiment.fps;
      experiment.handle = fileName;
      experiment.folder = [fpa filesep];
      experiment.saveFile = [experiment.name '.exp'];
  end  
  otherwise
    logMsg('Invalid extension', 'e');
    barCleanup(params);
    return;
end

%%% HACK
if(isfield(experiment, 'handle'))
  try
    [~, ~, fpc] = fileparts(experiment.handle);
    experiment.extension = lower(fpc);
  catch
  end
end

%--------------------------------------------------------------------------
barCleanup(params);
%--------------------------------------------------------------------------


% if(params.verbose)
%   try
%     [~, fname, ext] = fileparts(experiment.handle);
%   catch
%     fname = [];
%     ext = [];
%   end
%   MSG = ['Experiment ' fname ext ' loaded'];
%   logMsg(sprintf('%s', [datestr(now, 'HH:MM:SS'), ' ', MSG '']), 'w');
%   logMsg(sprintf('----------------------------------'));
%   logMsg(sprintf('Name:       %s', experiment.name));
%   logMsg(sprintf('File:       %s', [fname ext]));
%   logMsg(sprintf('Folder:     %s', experiment.folder));
%   logMsg(sprintf('Frames:     %d', experiment.numFrames));
%   logMsg(sprintf('Framerate:  %.2f fps', experiment.fps));
%   logMsg(sprintf('Duration:   %.2f s', experiment.totalTime));
%   logMsg(sprintf('Width:      %d px', experiment.width));
%   logMsg(sprintf('Height:     %d px', experiment.height));
%   logMsg(sprintf('Pixel type: %s', experiment.pixelType));
% end

end