function generateFullExportFigureMenu(hFig, defaultName)
% GENERATEFULLEXPORTFIGUREMENU Generates the default menu to export figures
%
% Copyright (C) 2016-2018, Javier G. Orlandi <javiergorlandi@gmail.com>
  ui = uimenu(hFig, 'Label', 'Export');
  uimenu(ui, 'Label', 'Figure',  'Callback', {@exportFigCallback, {'*.png';'*.tiff';'*.pdf'}, defaultName});
end