function menuAbout(~, ~, appFolder)
  hFig = figure('name', 'About', 'NumberTitle', 'off',...
    'toolbar','none','menubar','none');
  hFig.Position = setFigurePosition(gcbf, 'width', 600, 'height', 700);
  %%% Message starts here
  
  netcalLogoSize = round([400 367]/2);
  netcalLogoURL = ['file://' appFolder '/internal/gui/images/logo_netcal_400.png'];
  netcalLogoURL = fixURL(netcalLogoURL);
  logosTogether = round([1800 724]/5);
  logosURL = ['file://' appFolder '/internal/gui/images/logos_together.jpg'];
  logosURL = fixURL(logosURL);
  headerText = ['<center>',...
    '<img width=' num2str(netcalLogoSize(1)) ' height=' num2str(netcalLogoSize(2)) ' src="' netcalLogoURL '">',...  
    '</img><br/>', ...
     '</center>'];
  license = fileread([appFolder filesep 'LICENSE.md']);
  license = strrep(license, sprintf('\n\n'), '<br/><br/>');
  licenseText = ['<b>License</b><p align="justify">',...
                 license, ...
                 '</p>'];
  
  thanks = '<b>Thanks</b><p>Many people should appear here, but for now you can check the list of people involved in this project <a href="http://www.itsnetcal.com/people/">here</a>.</p>';
  
  fundingLogos = round([1257 259]/3.5);
  fundingLogosURL = ['file://' appFolder '/internal/gui/images/funding_logos.jpg'];
  fundingLogosURL = fixURL(fundingLogosURL);
  funding = ['<b>Funding</b><p>This project has been partially funded by</p>',...
             '<center>',...
             '<img width=' num2str(logosTogether(1)) ' height=' num2str(logosTogether(2)) ' src="' logosURL '">',...  
             '</img><br/>', ...
             '<img width=' num2str(fundingLogos(1)) ' height=' num2str(fundingLogos(2)) ' src="' fundingLogosURL '">',...  
             '</img>',...
             '</center>'];

  htmlStrings = ['<html><body>',...
                 headerText,...
                 '<hr/>', ...
                 thanks, ...
                 '<hr/>', ...
                 funding, ...
                 '<hr/>', ...
                 licenseText, ...
                 '</body></html>',...
                 ];


  %%% Message ends here
  import com.mathworks.mlwidgets.html.*;


  parent = hFig;
  % Create the Java browser component
  self.jbrowser = javaObjectEDT(com.mathworks.mlwidgets.help.LightweightHelpPanel);
  [self.browser, self.container] = javacomponent(self.jbrowser, ...
      [0 0 1 1], parent);
  self.htmlComponent = self.jbrowser.getLightweightBrowser();

  gap = 0.025;
  set(self.container, 'Units', 'norm', 'position', [gap, gap, 1-2*gap, 1-2*gap])
  
  %self.htmlComponent.setHtmlText(htmlStrings);
  self.TemporaryDirectory = tempdir();
  
  self.contentFilename = fullfile(self.TemporaryDirectory, sprintf('%s.html', java.util.UUID.randomUUID));
  if ~exist(self.TemporaryDirectory, 'dir')
    mkdir(self.TemporaryDirectory);
  end
  
  fid = fopen(self.contentFilename, 'w');
  fprintf(fid, '%s', htmlStrings);
  fclose(fid);
  self.htmlComponent.load(sprintf('file://%s', self.contentFilename));
end