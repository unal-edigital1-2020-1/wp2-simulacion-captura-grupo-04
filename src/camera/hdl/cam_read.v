`timescale 10ns / 1ns

module cam_read #(
		parameter AW = 15 
		)(
		input rst,
		input CAM_PCLK,
		input CAM_VSYNC,
		input CAM_HREF,
		input [7:0] CAM_px_data,
		input Photo_button,
		input Video_button,

		output reg [AW-1:0] DP_RAM_addr_in = 0,
		output reg [11:0] DP_RAM_data_in = 0,
		output reg DP_RAM_regW = 0
   );
	
	reg [2:0] state=1;
	reg pas_vsync = 0;
	reg cont = 1'b0;
	//reg [15:0] cont_href=16'h0000;
	reg pas_href= 0;
	reg [15:0] cont_pixel=16'h0000;
	reg [15:0] cont_pclk=16'h0000;
	always@(posedge CAM_PCLK) begin
		if (rst) begin
		
		  DP_RAM_addr_in=0;
		  //cont_href[15:0]=16'h0000;
		  state=1;pas_vsync=0;
			
		end else 
		
		//Maquina de estados		
		
		case(state) 					
			
		1:		// Vuelta a cero
			begin
				//cont_href[15:0]=16'h0000;
				DP_RAM_addr_in=15'b1111_1111_1111_111;								
				if(pas_vsync && !CAM_VSYNC) begin
				    state=2;
				end
			end
			
		2:		// Contador de href
			begin
				if(!pas_href && CAM_HREF) begin
						//cont_href = cont_href +1;
						cont_pixel = 0;
						state = 3;
					    DP_RAM_data_in[11:8] = {CAM_px_data[3:0]};
						DP_RAM_regW = 0;
						cont = ~cont;
						cont_pclk = cont_pclk + 1;
					
				end 
				else if(CAM_VSYNC) 
						state=1;
				else if(Photo_button)
						state = 4;
			end
			
		3:		// Captura de datos
		begin
			if(CAM_HREF) begin  
				if (cont==0)
				begin
					DP_RAM_data_in[11:8] = {CAM_px_data[3:0]};
					DP_RAM_regW = 0;
					cont_pclk = cont_pclk + 1;
				end
				else 
				begin
					DP_RAM_data_in[7:0] = {CAM_px_data[7:0]};
					DP_RAM_regW = 1;
					if(DP_RAM_addr_in < 19199|DP_RAM_addr_in==15'b1111_1111_1111_111) DP_RAM_addr_in = DP_RAM_addr_in + 1;
					cont_pixel = cont_pixel +1;
					
				end
				cont = ~cont;
				
			end else state=2;
		end
		
		4:		// "Tomar foto"		
		begin
			DP_RAM_regW = 0;
			
			if(Video_button)
				state = 1;
		end
		endcase
		
		pas_vsync = CAM_VSYNC;
	end

endmodule
