function htmlStrings = getHtmlColormapNames(initialOrder, width, height)
baseFolder = fileparts(mfilename( 'fullpath' ));
if(nargin == 0)
  initialOrder = [];
end
if(nargin < 2)
  width = 115;
end
if(nargin < 3)
  height = 12;
end

checkableFolders = {[docroot filesep 'matlab' filesep 'ref' filesep], [baseFolder filesep '..' filesep 'external' filesep 'colormaps' filesep]};
iconFiles = [];
folderList = [];
for i = 1:numel(checkableFolders)
  newFiles = dir([checkableFolders{i} 'colormap_*.png']);
  folderList = [folderList, repmat(checkableFolders(i), 1, length(newFiles))];
  iconFiles = [iconFiles; newFiles];
end
%colormapNames = regexprep({iconFiles.name}, '.*_(.*).png', '$1');
colormapNames = regexprep({iconFiles.name}, '^colormap*_(.*).png', '$1');

for i = numel(initialOrder):-1:1
  targetPosition = find(strcmp(colormapNames,initialOrder{i}));
  if(~isempty(targetPosition))
      colormapNames = [colormapNames(targetPosition), colormapNames];
      folderList = [folderList(targetPosition), folderList];
      colormapNames(targetPosition+1) = [];
      folderList(targetPosition+1) = [];
  end
end

% Hack for the weird parula
colormapNamesLabels = colormapNames;
invalid = find(strcmp('parula_update17a', colormapNamesLabels));
if(~isempty(invalid))
  colormapNamesLabels{invalid} = 'parula';
end

% htmlStrings = strcat(['<html><img width=' num2str(width) ' height=' num2str(height) ' src="file://' ...
%   docroot filesep 'matlab' filesep 'ref' filesep 'colormap_'], folderList', colormapNames',...
%   '.png">', colormapNames');
htmlStrings = strcat(['<html><img width=' num2str(width) ' height=' num2str(height) ' src="file://'], ...
  folderList', 'colormap_', colormapNames', '.png">', colormapNamesLabels');

if(strcmp(filesep,'\'))
    htmlStrings = strrep(htmlStrings, '\', '/'); % Windows hack
    htmlStrings = strrep(htmlStrings, '://', ':///'); % Windows hack
end