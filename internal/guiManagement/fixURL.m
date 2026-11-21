function URL = fixURL(URL)
% So they work in windows
if(strcmp(filesep,'\'))
  URL = strrep(URL, '\', '/');
  %URL = strrep(URL, '://', ':///');
  % Only when there are two!
  URL = regexprep(URL, '://(?!/)', ':///');
end