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
	input [7:0] CAM_px_data,

	output reg [11:0] DP_RAM_data_in,
	output reg [15:0] DP_RAM_addr_in,
	output reg DP_RAM_regW
	//input btn
   );
	
	reg cont=1'b0;
	reg [7:0] color;
	
	always@(posedge PCLK)
	begin
		if(HREF & ~VSYNC & DP_RAM_addr_in != 19200)
		begin			
			color[0] = CAM_px_data[0];
			color[1] = CAM_px_data[1];
			color[2] = CAM_px_data[2];
			color[3] = CAM_px_data[3];
			color[4] = CAM_px_data[4];
			color[5] = CAM_px_data[5];
			color[6] = CAM_px_data[6];
			color[7] = CAM_px_data[7];

			
			
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
		if(DP_RAM_addr_in==19200)
			DP_RAM_addr_in = 0;
			
		
	end
	
endmodule
