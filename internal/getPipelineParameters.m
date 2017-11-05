function [functionName, parametersClass, functionHandle, requiredFields, producedFields, parentGroups, functionType]  = getPipelineParameters(file)
% GETPIPELINEPARAMETERS gets the pipeline parameters from a function file
%
% USAGE:
%   functionName, requiredFields, producedFields]  = getPipelineParameters(file)
%
% INPUT arguments:
%   file - .m file containing possible pipeline parameters
%
% OUTPUT arguments:
%   functionName - name (descriptive) of the function
%
%   parametersClass - class containing function parameters
%
%   functionHandle - function handle (filename essentially)
%
%   requiredFields - fields the experiment should have for the function to work
%
%   producedFields - fields that will be produced as a result of this function
%
%   parentGroups - groups to where this function belongs (in the function list)
%
% EXAMPLE:
%   [functionName, parametersClass, functionHandle, requiredFields, producedFields]  = getPipelineParameters(file)
%
% Copyright (C) 2016-2017, Javier G. Orlandi <javierorlandi@javierorlandi.com>
%
% See also netcal

fID = fopen(file,'r');
if(fID == -1)
  return;
end
block = {};
foundGoodBlock = false;
while(~feof(fID))
  line = strrep(strtrim(fgetl(fID)),'"',''''); % There's a bug with ""
  if(~isempty(line))
    block{end+1} = strtrim(line);
  end
  if(~isempty(line) && ~feof(fID))
    continue;
  end
  
  for i = 1:length(block)
    if(any(regexp(block{1},'% PIPELINE*')))
      foundGoodBlock = true;
      mode = 'projexp';
    elseif(any(regexp(block{1},'% EXPERIMENT PIPELINE*')))
      foundGoodBlock = true;
      mode = 'experiment';
    elseif(any(regexp(block{1},'% PROJECT PIPELINE*')))
      foundGoodBlock = true;
      mode = 'project';
    elseif(any(regexp(block{1},'% DEBUG PIPELINE*')))
      foundGoodBlock = true;
      mode = 'projexpDebug';
    elseif(any(regexp(block{1},'% DEBUG EXPERIMENT PIPELINE*')))
      foundGoodBlock = true;
      mode = 'experimentDebug';
    elseif(any(regexp(block{1},'% DEBUG PROJECT PIPELINE*')))
      foundGoodBlock = true;
      mode = 'projectDebug';
    else
      break;
    end
  end
  if(foundGoodBlock)
    break;
  end
  block = {};
end
strList = {'% name:', '% optionsClass:', '% requiredFields:', '% producedFields:', '% parentGroups:'};

functionName = [];
parametersClass = [];
functionHandle = [];
requiredFields = [];
producedFields = [];
parentGroups = [];
functionType = [];

if(foundGoodBlock)
  [~, functionHandle, ~] = fileparts(file);
  functionType = mode;
  for i = 1:length(block)
    for j = 1:length(strList)
      if(strfind(block{i}, strList{j}))
        newStr = block{i}((strfind(block{i}, strList{j})+length(strList{j})):end);
        switch strList{j}
          case '% name:'
            functionName = strtrim(newStr);
          case '% optionsClass:'
             parametersClass = strtrim(newStr);
          case '% requiredFields:'
             requiredFields = strtrim(strsplit(newStr, ','));
          case '% producedFields:'
            producedFields = strtrim(strsplit(newStr, ','));
          case '% parentGroups:'
            parentGroups = strtrim(strsplit(newStr, ','));
        end
      end
    end
  end
end
  
fclose(fID);