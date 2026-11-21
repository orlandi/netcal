function menuList = pluginChecker(appFolder, menuList)
  % Reset the list
  for it = 1:length(menuList.plugins.list)
    delete(menuList.plugins.list(it));
  end
  menuList.plugins.list = [];

  pluginList = dir([appFolder filesep 'plugins' filesep '*.m']);
  if(~isempty(pluginList))
    menuList.plugins.root.Enable = 'on';
    for i = 1:length(pluginList)
      [~, fpb, fpc] = fileparts(pluginList(i).name);
      if(~strcmpi(fpc, '.m'))
          continue;
      elseif(strcmpi(fpb(1), '.'))
          continue;
      end
      pluginName = fpb;
      menuList.plugins.list = [menuList.plugins.list; ...
                              uimenu(menuList.plugins.root, 'Label', pluginName, 'Enable', 'on', ...
                                     'Checked', 'off', 'Callback', eval(['@' pluginName]))];
    end
  end
end