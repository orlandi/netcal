function generateFullExportFigureMenu(hFig, defaultName)
% GENERATEFULLEXPORTFIGUREMENU Generates the default menu to export figures
%
% Copyright (C) 2015, Javier G. Orlandi <javierorlandi@javierorlandi.com>
  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf'}, defaultName});
end