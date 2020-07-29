`timescale 10ns / 1ns

module test_cam(
    input wire clk,           // board clock: 100 MHz 
    input wire rst,    // reset button
    
	// VGA input/output  
    output wire VGA_Hsync_n,  // horizontal sync output
    output wire VGA_Vsync_n,  // vertical sync output
    output wire [3:0] VGA_R,	// 4-bit VGA red output
    output wire [3:0] VGA_G,  // 4-bit VGA green output
    output wire [3:0] VGA_B,  // 4-bit VGA blue output
	

	//output wire clk25M,
	//cables de revison de los lectura y escritura de datos
	//wire [14:0]  DP_RAM_addr_in,
	//wire [11:0] DP_RAM_data_in,
	//wire DP_RAM_regW,
	//reg [14:0] DP_RAM_addr_out,
	//wire [11:0] data_mem,
	
	//CAMARA input/output
	
	output wire CAM_xclk,		// System  clock imput
	//output wire CAM_pwdn,		// power down mode 
	//output wire CAM_reset,		// clear all registers of cam
	
	input wire CAM_PCLK,				// Sennal PCLK de la camara
	input wire CAM_HREF,				// Sennal HREF de la camara
	input wire CAM_VSYNC,				// Sennal VSYNC de la camara
	input wire [7:0] CAM_px_data,     // Bit n de los datos del pixel
    input wire Photo_button,
    input wire Video_button
    
    //output wire Locked
   );

    wire [14:0]  DP_RAM_addr_in;
	wire [11:0] DP_RAM_data_in;
	wire DP_RAM_regW;
	reg [14:0] DP_RAM_addr_out;
	wire [11:0] data_mem;
	
// TAMAÑO DE ADQUISICION DE LA CAMARA 
parameter CAM_SCREEN_X = 160; 
parameter CAM_SCREEN_Y = 120; 

localparam AW = 15; // LOG2(CAM_SCREEN_X*CAM_SCREEN_Y)
localparam DW = 12; //bits por pixel

//CLK
wire clk100M;
//wire clk25M;
//wire clk24M;

// Conexión dual por ram
//wire [AW-1: 0] DP_RAM_addr_in;		
//wire [DW-1: 0] DP_RAM_data_in;
//wire DP_RAM_regW;

//reg  [AW-1: 0] DP_RAM_addr_out;	

// Conexion VGA Driver
//wire [14:0] data_mem;       // Salida de dp_ram al driver VGA
wire [DW-1:0]data_RGB444;  // salida del driver VGA al puerto
wire [9:0]VGA_posX;		   // Determinar la pos de memoria que viene del VGA
wire [9:0]VGA_posY;		   // Determinar la pos de memoria que viene del VGA


/* ****************************************************************************
la pantalla VGA es RGB 444, y el almacenamiento en memoria se hace 444 
**************************************************************************** */

    assign VGA_R = {data_RGB444[11:8]};
    assign VGA_G = {data_RGB444[7:4]};
    assign VGA_B = {data_RGB444[3:0]};

/* ****************************************************************************
Asignacion de las seales de control xclk pwdn y reset de la camara 
**************************************************************************** */

//assign CAM_xclk = clk24M;
//assign CAM_pwdn = 0;			// power down mode 
//assign CAM_reset = 0;

/* ****************************************************************************
  Este bloque se debe modificar segun sea le caso. El ejemplo esta dado para
  fpga Spartan6 lx9 a 32MHz.
  usar "tools -> Core Generator ..."  y general el ip con Clocking Wizard
  el bloque genera un reloj de 25Mhz usado para el VGA  y un relo de 24 MHz
  utilizado para la camara , a partir de una frecuencia de 32 Mhz
**************************************************************************** */
assign clk100M =clk;   
clk_100MHZ_to_25M_24M pll(
  .CLK_IN1(clk),
  .CLK_OUT1(CAM_xclk),
  .CLK_OUT2(clk25M),
  .RESET(rst)
  //.LOCKED(Locked)
 );

/*****************************************************************************
Instancia del modulo disennado cam_read - Captura de datos y downsampler
**************************************************************************** */
 cam_read Camera_Read(
		// Entradas
		.rst(rst),
		.CAM_PCLK(CAM_PCLK),
		.CAM_VSYNC(CAM_VSYNC),
		.CAM_HREF(CAM_HREF),
		.CAM_px_data(CAM_px_data),
		.Photo_button(Photo_button),
		.Video_button(Video_button),
		
		// Salidas
		.DP_RAM_addr_in(DP_RAM_addr_in),
		.DP_RAM_data_in(DP_RAM_data_in),
		.DP_RAM_regW(DP_RAM_regW)
   );


/* ****************************************************************************
buffer_ram_dp buffer memoria dual port y reloj de lectura y escritura separados
Se debe configurar AW  segn los calculos realizados en el Wp01
se recomiendia dejar DW a 12, con el fin de optimizar recursos  y hacer RGB 444
**************************************************************************** */
buffer_ram_dp #(AW,DW)
	DP_RAM(  
	//entradas
	
	.clk_w(CAM_PCLK), 
	.addr_in(DP_RAM_addr_in), 
	.data_in(DP_RAM_data_in),
	.regwrite(DP_RAM_regW), 
	.clk_r(clk25M), 
	.addr_out(DP_RAM_addr_out),
	//.reset(rst),
	//salidas
	.data_out(data_mem)
	
);
	
/* ****************************************************************************
VGA_Driver640x480
**************************************************************************** */
VGA_Driver640x480 VGA640x480
(
    //entradas 
	.rst(rst),
	.clk(clk25M), 				// 25MHz  para 60 hz de 640x480
	.pixelIn(data_mem), 		// entrada del valor de color  pixel RGB 444 
	//salidas 
	.pixelOut(data_RGB444),     // salida del valor pixel a la VGA 
	.Hsync_n(VGA_Hsync_n),	    // sennal de sincronizacion en horizontal negada
	.Vsync_n(VGA_Vsync_n),	    // sennal de sincronizacion en vertical negada 
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
			DP_RAM_addr_out=160*120;
		else
			DP_RAM_addr_out=VGA_posX+VGA_posY*CAM_SCREEN_X;//DP_RAM_addr_out=CAM_SCREEN_X*CAM_SCREEN_Y;
end

endmodule
