function success = isSubField(mainStruct, subStructName, len)
if(nargin < 3)
  len = [];
end
separatedStruct = strtrim(strsplit(subStructName,'.'));
subStruct = mainStruct;

for i = 1:length(separatedStruct)
  curField = separatedStruct{i};
  if(~isfield(subStruct, curField))
    success = 0;
    return;
  else
    subStruct = subStruct.(curField);
  end
end
if(isempty(len))
  success = true;
elseif(len <= length(subStruct))
  success = true;
else
  success = false;
end

  