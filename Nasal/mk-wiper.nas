# wiper action
setlistener("/controls/special/wiper-switch", func() {
  wiper_action();  
}, 0, 1);

var wiper_action = func(){

    var ws = getprop("/controls/special/wiper-switch") or 0;
    var d = getprop("/controls/special/wiper-deg") or 0;
    
 		if(ws){
 								
 		  if(ws == 1){
				if (d > 53){        
					interpolate("/controls/special/wiper-deg", -50, 2);  
				}
				if (d < -48){        
					interpolate("/controls/special/wiper-deg", 55,  2);  
				}
				
				settimer(wiper_action, 6);
			}
 		
 		  if(ws == 2){
				if (d > 53){        
					interpolate("/controls/special/wiper-deg", -50, 2);  
				}
				if (d < -48){        
					interpolate("/controls/special/wiper-deg", 55,  2);  
				}
				
				settimer(wiper_action, 2.5);
			}
			
 		  if(ws == 3){
				if (d > 53){        
					interpolate("/controls/special/wiper-deg", -50, 1);  
				}
				if (d < -48){        
					interpolate("/controls/special/wiper-deg", 55,  1);  
				}
				
				settimer(wiper_action, 1);
			}
					
 		  if(ws == 4){
				if (d > 53){        
					interpolate("/controls/special/wiper-deg", -50, 0.6);  
				}
				if (d < -48){        
					interpolate("/controls/special/wiper-deg", 55,  0.6);  
				}
				
				settimer(wiper_action, 0.6);
			}

			

		  
		}else{
			interpolate("/controls/special/wiper-deg", 55,  1);
		}   


};
