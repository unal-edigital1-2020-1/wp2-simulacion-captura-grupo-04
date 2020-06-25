`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.06.2020 20:15:17
// Design Name: 
// Module Name: captura_de_datos_downsampler
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module captura_de_datos_downsampler(
    input PCLK,
	input HREF,
	input VSYNC,
	input D0,
	input D1,
	input D2,
	input D3,
	input D4,
	input D5,
	input D6,
	input D7,

	output reg [11:0] DP_RAM_data_in,
	output reg [15:0] DP_RAM_addr_in,
	output reg DP_RAM_regW
	//input btn
   );
	
	reg cont=1'b0;
	reg [11:0] color;
	
	always@(posedge PCLK)
	begin
		if(HREF & ~VSYNC & DP_RAM_addr_in != 19200)
		begin			
			color[0] = D0;
			color[1] = D1;
			color[2] = D2;
			color[3] = D3;
			color[4] = D4;
			color[5] = D5;
			color[6] = D6;
			color[7] = D7;

			
			
			if (cont==0)
			begin
				DP_RAM_data_in <= {color[3:0],DP_RAM_data_in[7:0]};
				DP_RAM_regW = 0;
			end
			else 
			begin
				DP_RAM_data_in <= {DP_RAM_data_in[11:8],color[7:0]};
				DP_RAM_regW = 1;
			end
			cont = cont+1;	
		end
	end
	
	always@(negedge PCLK)
	begin
		if(HREF & ~VSYNC & (cont == 1))
		begin
			DP_RAM_addr_in =DP_RAM_addr_in+1;
		end
		
		/* & foto == 0
		*if(btn)
			foto=1
			 & ~foto*/
		
		if(~HREF & VSYNC)
			DP_RAM_addr_in = 0;
			
		
	end
	
endmodule
