%% Useful Notes
%
% We hope that you will enjoy the _Brick_ Toolbox! Please find here a few
% additional information.

%% Installation
% Add only the main |brick| folder to the Matlab path (not the
% subdirectories).
%
% A new menu should appear in the Help window (type '|doc|'). If it is not the
% case, make sure that in the Matlab Preferences, Help tab, 'All products'
% is selected.

%% Syntax of functions
% The _Brick_ toolbox does not follow Matlab convention of the 'H-line',
% i.e. that the first line in the help of a function should be a short
% description of what the function is doing. Instead, it displays the
% different possible syntaxes. Let us see some examples:

%%
%  function b = fn_interprows(a,subrate[,method[,extrap]])

%%
% Brackes |[]| indicate optional arguments. Thus here, |method| and
% |extrap| are optionals; note that it is 
% necessary to provide |method| in order to be able to provide |extrap|

%%
%  function M = fn_savemovie(a[,fname][,clip][,fps][,zoom][,map][,hf])

%%
% Here on the contrary, all the optional can be provided alone (and in most
% functions, they can also be provided in all different orders). The
% function figures out by itself for example that
% |fn_savemovie(data,2,15,'mymovie.avi')| means that 2 is a zoom factor, 15
% a number of frames per second and 'mymovie.avi' a file name.



