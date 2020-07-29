`timescale 10ns / 1ns	

module buffer_ram_dp#( 
	parameter AW = 15, // Cantidad de bits  de la direccin 
	parameter DW = 12, // cantidad de Bits de los datos 
	parameter   imageFILE= "C:/Xilinx/Digital/Camera/imagen.men"
	)
	(  
	input  clk_w, 
	input  [AW-1: 0] addr_in, 
	input  [DW-1: 0] data_in,
	input  regwrite, 
	
	input  clk_r, 
	input [AW-1: 0] addr_out,
	output reg [DW-1: 0] data_out
	//input reset
	);

// Calcular el nmero de posiciones totales de memoria 
localparam NPOS = 2 ** AW; // Memoria
//localparam imagesize=160*120;
 reg [DW-1: 0] ram [0: NPOS-1]; 

always @(posedge clk_w) begin 
       if (regwrite == 1) begin
			if(addr_in<=19199) ram[addr_in] <= data_in;		//Limitador de uso de memoria
			else ram[addr_in] <= 12'h000;
			end
end
//	 escritura  de la memoria port 1 
//always @(posedge clk_w) begin 
//       if (regwrite == 1) 
//             ram[addr_in] <= data_in;
//end

//	 Lectura  de la memoria port 2 
always @(posedge clk_r) begin 
		data_out <= ram[addr_out]; 
end

initial begin
	$readmemh(imageFILE, ram);
	ram[15'b111111111111111] = 12'h000;  
end

/*
always @(posedge clk_w) begin 
	if (reset) begin
		$readmemh(imageFILE, ram);
	end
end
*/

endmodule