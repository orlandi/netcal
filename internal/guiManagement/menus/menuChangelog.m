function menuChangelog(~, ~, appFolder)
  hFig = figure('name', 'Changelog', 'NumberTitle', 'off',...
    'toolbar','none','menubar','none');
  hFig.Position = setFigurePosition(gcbf, 'width', 600, 'height', 700);
  

  changelogFile = fileread([appFolder filesep 'README.md']);
  changeLogStart = strfind(changelogFile, '# Change Log');
  changelogFile = changelogFile(changeLogStart:end);
  %self = newMarkdownPanel(hFig, changelogFile);
  self = newMarkdownPanel24(hFig, changelogFile);
  %self = MarkdownPanel('Content',changelogFile);
end