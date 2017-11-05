function success = checkUserModifiedFile(file)
% CHECKUSERMODIFIEDFILE checks if a .m file was modified by the user
%
% USAGE:
%   success = checkUserModifiedFile(file)
%
% INPUT arguments:
%   file - .m file containing possible pipeline parameters
%
% OUTPUT arguments:
%   success - true if the file was modified by the user
%
% EXAMPLE:
%   success = checkUserModifiedFile(netcal.m)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also netcal
% MODIFIED

success = false;

fID = fopen(file,'r');
if(fID == -1)
  return;
end
block = {};
foundGoodBlock = false;
blockCount = 0;
while(~feof(fID))
  line = strrep(strtrim(fgetl(fID)),'"',''''); % There's a bug with ""
  if(~isempty(line))
    block{end+1} = strtrim(line);
  end
  if(~isempty(line) && ~feof(fID))
    continue;
  end
  blockCount = blockCount + 1;
  % Essentially, if we are outside the top comments and have started defining stuff, break
  if(~isempty(block) && blockCount > 1)
    if(~strcmp(block{1}(1), '%'))
      break;
    end
  end
  % Check in the top blocks for the modified line
  for i = 1:length(block)
    if(any(regexp(block{i},'% MODIFIED*')))
      foundGoodBlock = true;
    end
  end
  % No need to continue
  if(foundGoodBlock)
    break;
  end
  block = {};
end
  
if(foundGoodBlock)
  success = true;
else
  success = false;
end

fclose(fID);
