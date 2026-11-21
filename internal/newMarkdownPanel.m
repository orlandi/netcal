function self = newMarkdownPanel(parent, content)
  url = 'https://helloacm.com/api/markdown/';
  options = weboptions('RequestMethod','post');
  try
    htmlContent = webwrite(url, ['s=' content], options);
  catch
    htmlContent = content;
  end
    
  %%% Message ends here
  import com.mathworks.mlwidgets.html.*;
  % For pre-HG2 browsers, specify the default to be HTMLPANEL
  if verLessThan('matlab', '8.4')
      HtmlComponentFactory.setDefaultType('HTMLPANEL');
  end

  % Create the Java browser component
  self = struct;
  self.jbrowser = HTMLBrowserPanel();
  [self.browser, self.container] = javacomponent(self.jbrowser, ...
      [0 0 1 1], parent);
  self.htmlComponent = self.jbrowser.getHtmlComponent();

  gap = 0.025;
  set(self.container, 'Units', 'norm', 'position', [gap, gap, 1-2*gap, 1-2*gap])
  
  self.htmlComponent.setHtmlText(htmlContent);
