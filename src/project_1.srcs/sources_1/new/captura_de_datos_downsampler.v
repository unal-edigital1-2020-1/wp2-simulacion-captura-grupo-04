`timescale 10ns / 1ns	
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

	output reg [11:0] DP_RAM_data_in=0,
	output reg [14:0] DP_RAM_addr_in=0,
	output reg DP_RAM_regW=0  
	//input btn
	
   );
	
	reg cont=1'b0;
//	always @ (posedge PCLK)
////  begin
////    if(rst)
////    begin
////        DP_RAM_regW=0;
////        DP_RAM_addr_in=0;
////        DP_RAM_data_in=0;
////        rst=0;
////    end
  
//  end
	
	always@(posedge PCLK)
	begin
		if(HREF & ~VSYNC ) //& DP_RAM_addr_in != 32768
		begin	
			if (cont==0)
			begin
				DP_RAM_data_in <= {CAM_px_data[3:0],DP_RAM_data_in[7:0]};
				DP_RAM_regW = 0;
			end
			else 
			begin
				DP_RAM_data_in <= {DP_RAM_data_in[11:8],CAM_px_data[7:0]};
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
		if(DP_RAM_addr_in==19199)
		begin
			DP_RAM_addr_in = 0;
		end	
		
	end
	
endmodule
