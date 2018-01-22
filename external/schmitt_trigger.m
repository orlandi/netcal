%SCHMITT TRIGGER
function y = schmitt_trigger(x,tL,tH)
% Modified to allow an arbitrary number of thresholds
% Javier Orlandi 2017

%x=rand(1,100);
%x=conv(x,ones(10,1)/10);

 limit=0;
if nargin<3
   disp('number of inputs arguments should be three');
end
   N=length(x);
  
   y=[length(x)];
  
if(numel(tL) == 1)
  tL = ones(size(x))*tL;
end
if(numel(tH) == 1)
  tH = ones(size(x))*tH;
end
   for i=1:N
       
       
      if ( limit ==0)
          
          y(i)=0;
          
      elseif (limit == 1)
           
           y(i)=1;
           
      end
       
       
      if (x(i)<=tL(i))
          limit=0; 
            y(i)=0;
          
      elseif( x(i)>= tH(i))         
          limit=1;  
          y(i)=1;
              
      end
      
         
   end
  
%   plot(x,'r','DisplayName','plot of x','LineWidth',1.5); hold on;
%   plot(y,'blue','DisplayName','plot of y','LineWidth',3); hold off;
%   legend('show');
%   
  
