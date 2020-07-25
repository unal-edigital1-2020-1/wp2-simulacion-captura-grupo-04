`timescale 10ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:46:19 11/04/2019 
// Design Name: 
// Module Name:    test_cam 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module test_cam(
    input wire clk,           // board clock: 100 MHz 
    input wire rst,
	 // reset button

	// VGA input/output  
    output wire VGA_Hsync_n,  // horizontal sync output
    output wire VGA_Vsync_n,  // vertical sync output
    output wire [3:0] VGA_R,	// 4-bit VGA red output
    output wire [3:0] VGA_G,  // 4-bit VGA green output
    output wire [3:0] VGA_B,  // 4-bit VGA blue output
	
	
	
	output wire [11:0] data_mem,
	output wire [14:0]  DP_RAM_addr_in,
	output wire [11:0] DP_RAM_data_in,
	output reg [14:0] DP_RAM_addr_out,
	//CAMARA input/output
	
	output wire CAM_xclk,		// System  clock imput
	output wire CAM_pwdn,		// power down mode 
	output wire CAM_reset,		// clear all registers of cam
	input CAM_PCLK,				// Sennal PCLK de la camara
	input CAM_HREF,				// Sennal HREF de la camara
	input CAM_VSYNC,				// Sennal VSYNC de la camara
	input [7:0] CAM_px_data     // Bit n de los datos del pixel

   );

// TAMANNO DE ADQUISICION DE LA CAMARA 
parameter CAM_SCREEN_X = 160; //320
parameter CAM_SCREEN_Y = 120; //120

localparam AW = 15; // LOG2(CAM_SCREEN_X*CAM_SCREEN_Y)
localparam DW = 12;



// El color es RGB 444
//localparam RED_VGA =   12'b111100000000;
//localparam GREEN_VGA = 12'b000011110000;
//localparam BLUE_VGA =  12'b000000001111;
// Clk 
wire clk100M;
wire clk25M;
wire clk24M;

// Conexion dual por ram


wire DP_RAM_regW;

//wire rst_Cam_read =1;
	
// Conexion VGA Driver

//wire [DW-1:0]data_RGB332;  // salida del driver VGA al puerto
wire [DW-1:0]data_RGB444;  // salida del driver VGA al puerto
wire [9:0]VGA_posX;		   // Determinar la pos de memoria que viene del VGA
wire [9:0]VGA_posY;		   // Determinar la pos de memoria que viene del VGA


/* ****************************************************************************
la pantalla VGA es RGB 444, pero el almacenamiento en memoria se hace 332
por lo tanto, los bits menos significactivos deben ser cero
**************************************************************************** */
//assign VGA_R = {data_RGB332[7:5],1'b0};
//assign VGA_G = {data_RGB332[4:2],1'b0};
//assign VGA_B = {data_RGB332[1:0],2'b00};

	assign VGA_R = {data_RGB444[11:8]};
	assign VGA_G = {data_RGB444[7:4]};
	assign VGA_B = {data_RGB444[3:0]};

/* ****************************************************************************
Asignacion de las seales de control xclk pwdn y reset de la camara 
**************************************************************************** */

assign CAM_xclk = clk24M;
assign CAM_pwdn = 0;			// power down mode 
assign CAM_reset = 0;

/* ****************************************************************************
  Este bloque se debe modificar segun sea le caso. El ejemplo esta dado para
  fpga Spartan6 lx9 a 32MHz.
  usar "tools -> Core Generator ..."  y general el ip con Clocking Wizard
  el bloque genera un reloj de 25Mhz usado para el VGA  y un relo de 24 MHz
  utilizado para la camara , a partir de una frecuencia de 32 Mhz
**************************************************************************** */
assign clk100M =clk;   /// revisar esto con nestor

clk_100MHZ_to_25M_24M pll(
  .CLK_IN1(clk),
  .CLK_OUT1(clk25M),
  .CLK_OUT2(clk24M),
  .RESET(rst)
  //.LOCKED()
 );

/* ****************************************************************************
captura_datos_downsampler
**************************************************************************** */

captura_de_datos_downsampler Capture_Downsampler(
	.PCLK(CAM_PCLK),
	.HREF(CAM_HREF),
	.VSYNC(CAM_VSYNC),
	.CAM_px_data(CAM_px_data),
	.DP_RAM_data_in(DP_RAM_data_in),
	.DP_RAM_addr_in(DP_RAM_addr_in),
	.DP_RAM_regW(DP_RAM_regW)
	);

/* ****************************************************************************
buffer_ram_dp buffer memoria dual port y reloj de lectura y escritura separados
Se debe configurar AW  segn los calculos realizados en el Wp01
se recomiendia dejar DW a 8, con el fin de optimizar recursos  y hacer RGB 332
**************************************************************************** */
buffer_ram_dp #(AW,DW)
	DP_RAM(  
	.clk_w(clk), 
	.addr_in(DP_RAM_addr_in), 
	.data_in(DP_RAM_data_in),
	.regwrite(DP_RAM_regW), 
	.clk_r(clk25M), 
	.addr_out(DP_RAM_addr_out),
	.data_out(data_mem)
	//.reset(rst)
);
	
/* ****************************************************************************
VGA_Driver640x480
**************************************************************************** */
VGA_Driver640x480 VGA640x480
(
	.rst(rst),
	.clk(clk25M), 				// 25MHz  para 60 hz de 640x480
	.pixelIn(data_mem), 		// entrada del valor de color  pixel RGB 332 
	.pixelOut(data_RGB444), // salida del valor pixel a la VGA 
	.Hsync_n(VGA_Hsync_n),	// sennal de sincronizacion en horizontal negada
	.Vsync_n(VGA_Vsync_n),	// sennal de sincronizacion en vertical negada 
	.posX(VGA_posX), 			// posicion en horizontal del pixel siguiente
	.posY(VGA_posY) 			// posicinn en vertical  del pixel siguiente

);

 
/* ****************************************************************************
Logica para actualizar el pixel acorde con la buffer de memoria y el pixel de 
VGA si la imagen de la camara es menor que el display VGA, los pixeles 
adicionales seran iguales al color del ultimo pixel de memoria 
**************************************************************************** */
always @ (VGA_posX, VGA_posY) begin
		if ((VGA_posX>CAM_SCREEN_X-1) |(VGA_posY>CAM_SCREEN_Y-1))
			//DP_RAM_addr_out=CAM_SCREEN_X*CAM_SCREEN_Y;
			DP_RAM_addr_out=160*120;
		else
			DP_RAM_addr_out=VGA_posX+VGA_posY*CAM_SCREEN_X;
end

endmodule
