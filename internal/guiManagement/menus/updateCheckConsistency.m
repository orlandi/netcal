function updateCheckConsistency(~, ~, updaterSource, DEVELOPMENT)
  if(nargin < 4)
    DEVELOPMENT = false;
  end
  success = true;
  fileList = webread([updaterSource 'fileList.txt']);
  if(ispc)
    fileList = strrep(fileList, '/', '\');
  end
  % Content hashes are optional (older servers only have the file list)
  serverHashes = containers.Map('KeyType', 'char', 'ValueType', 'char');
  try
    hashList = webread([updaterSource 'hashList.txt']);
    if(ispc)
      hashList = strrep(hashList, '/', '\');
    end
    hashLines = strsplit(strtrim(hashList), '\n');
    for i = 1:length(hashLines)
      hashTokens = strsplit(strtrim(hashLines{i}), ' ');
      if(numel(hashTokens) >= 2)
        serverHashes(strjoin(hashTokens(1:end-1), ' ')) = hashTokens{end};
      end
    end
  catch
    logMsg('No hash list found on the server. Comparing only file sizes', 'w');
  end
  logMsgHeader('Checking file consistency', 'start');
  % Turn each line into 2 strings to process and compare
  fileListLines = strsplit(fileList, '\n');
  serverFileList = {};
  for i = 1:length(fileListLines)
    splitLine = strsplit(fileListLines{i});
    if(length(splitLine) > 2)
      splitLine = {strjoin(splitLine(1:end-1)), str2double(splitLine{end})};
    else
      splitLine{2} = str2double(splitLine{end});
    end
    currFile = dir(splitLine{1});
    serverFileList{end+1} = splitLine{1};
    if(isempty(currFile))
      success = false;
      logMsg(sprintf('File %s is missing', splitLine{1}));
    elseif(currFile.bytes ~= splitLine{2})
      success = false;
      logMsg(sprintf('File %s appears to be the wrong size (%d vs %d)', splitLine{1}, currFile.bytes, splitLine{2}));
    elseif(isKey(serverHashes, splitLine{1}) && ~strcmp(fileMD5(splitLine{1}), serverHashes(splitLine{1})))
      success = false;
      logMsg(sprintf('File %s has the right size but different content', splitLine{1}));
    end
  end
  % Now check for unknown .m files
  folders = {'*.m', 'internal', 'external', 'docs', 'installDependencies'}; % Not plugins
  if(DEVELOPMENT)
    folders{end+1} = 'development';
  end
  for i = 1:length(folders)
    % This is for folders and subfolders
    if(exist(folders{i}, 'dir'))
      fileList = getAllFiles(folders{i});
      for j = 1:length(fileList)
        if(any(regexp(fileList{j}, '(\.m)$')) && ~any(cellfun(@(x) strcmpi(x, fileList{j}), serverFileList)))
          logMsg(sprintf('Found file %s that should not be there. Consider deleting it if you do not know what it is', fileList{j}));
          success = false;
        end
      end
    else
      fileList = rdir(folders{i});
      for j = 1:length(fileList)
        if(any(regexp(fileList(j).name, '(\.m)$')) && ~any(cellfun(@(x) strcmpi(x, fileList(j).name), serverFileList)))
          logMsg(sprintf('Found file %s that should not be there. Consider deleting it if you do not know what it is', fileList(j).name));
          success = false;
        end
      end
    end
  end
  if(success)
    logMsgHeader('Everything appears to be ok', 'finish');
  else
    logMsgHeader('Some inconsistencies were detected. Please force an update', 'finish');
  end
end