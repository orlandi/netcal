classdef example_interface < interface
    % This is an example of how to build a GUI using class syntax with the
    % help of the two following tools:
    % - a generic parent class 'interface' providing functionalities for
    %   positioning graphic elements and some default menu.
    % - 'fn_propcontrol' creates controls automatically linked to
    %   the object properties.
    %
    % The simple interface created here includes a text control and an axes
    % where the text is reproduced in color. A menu allows changing the
    % color and defines a default color. These text and color properties
    % can also be changed by command, for example try typing in Matlab:
    %   E = example_interface;
    %   E.x = 'Hello World!';
    %   E.color = 'blue';
    
    % properties: we define here properties specific to example_interface,
    % but not also that it has the following properties inherited from the
    % parent class interface: hf, grob, options, menus, interfacepar
    properties (AbortSet=true, SetObservable=true) % SetObservable=true is necessary for using fn_propcontrol function
        x = ';-)';      % the string (already initialized here)
        color           % the color (will be initialized later)
    end
    
    % Initializations
    methods
        function E = example_interface(value)
            % class constructor
            
            % default options
            defaultoptions = struct('color','red');

            % figure
            hf = figure;
            
            % initial call to the parent constructor
            E = E@interface(hf,'My Interface',defaultoptions);
            
            % init graphic objects - no need to define their positions!!!
            % (an axes)
            E.grob.ha = axes('parent',hf);
            % (a control: use function 'fn_propcontrol' to create it, so it
            % will be automatically linked to property x)
            E.grob.hu = fn_propcontrol.createcontrol(E,'x','char',{'parent',E.hf,'backgroundcolor','w'});
            
            % call parent method 'interface_end' to handle the positions of
            % objects and create the menus
            interface_end(E)
            
            % set data value
            % note that the default options have been redefined to their
            % last saved value  
            % note also that this will cause an automatic update of the
            % display
            if nargin>1
                E.x = value;
            end
            E.color = E.options.color;
            
        end
        function init_menus(E)
            % initialization of menus: this function will be called
            % automatically during the call to interface_end(E); indeed,
            % interface creates its own menu with several options, and here
            % we can create additional menus
            
            % first put the default interface menu if we want it
            init_menus@interface(E)
            
            % delete the menu if it already exists (this happens when user
            % selects the 'reinit_menus' option)
            if isfield(E.menus,'color') && ishandle(E.menus.color), delete(E.menus.color), end
            
            % the menu
            m = uimenu('parent',E.hf,'label','color');
            E.menus.color = m;
            
            % use function fn_propcontrol to create a set of sub-menus to
            % control the color property 'color'
            fn_propcontrol(E,'color',{'menuval' 'black' 'blue' 'red' 'green' 'yellow'},{'parent',m});

            % additional menu entries for default color
            uimenu(m,'label','make current color default','callback',@(u,e)makedefaultcol(E))
            uimenu(m,'label','return to default color','callback',@(u,e)backdefaultcol(E))
        end
    end
    
    % Actions
    methods
        function set.x(E,value)
            % some checks
            if ~ischar(value), error argument, end
            % change property value
            E.x = value;
            % update display
            displaytext(E)
        end
        function set.color(E,c)
            % change property value
            E.color = c;
            % update display
            displaytext(E)
        end
        function makedefaultcol(E)
            % change the options and save it 
            E.options.color = E.color;
            saveoptions(E)
        end
        function backdefaultcol(E)
            E.color = E.options.color;
        end
        function displaytext(E)
            cla(E.grob.ha)
            text(.1,.2,E.x,'color',E.color,'fontsize',50,'fontweight','bold')
        end
    end
    
end
