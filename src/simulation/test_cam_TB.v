`timescale 10ns / 1ns

module test_cam_TB;

	// Inputs
	reg clk;
	reg rst;
	reg pclk;
	reg CAM_vsync;
	reg CAM_href;
	reg [7:0] CAM_px_data;

	// Outputs
	wire VGA_Hsync_n;
	wire VGA_Vsync_n;
	wire [3:0] VGA_R;
	wire [3:0] VGA_G;
	wire [3:0] VGA_B;
	wire CAM_xclk;
	wire CAM_pwdn;
	wire CAM_reset;

	// Instantiate the Unit Under Test (UUT)
    wire [11:0] data_mem;
	wire [14:0] DP_RAM_addr_in;
	wire [11:0] DP_RAM_data_in;
	wire [14:0] DP_RAM_addr_out;

	test_cam uut (
	    //inputs 
		.clk(clk), 
		.rst(rst), 
		.VGA_Hsync_n(VGA_Hsync_n), 
		.VGA_Vsync_n(VGA_Vsync_n), 
		.VGA_R(VGA_R), 
		.VGA_G(VGA_G), 
		.VGA_B(VGA_B), 
		
	   .data_mem(data_mem),
	   .DP_RAM_addr_in(DP_RAM_addr_in),
	   .DP_RAM_data_in(DP_RAM_data_in),
	   .DP_RAM_addr_out(DP_RAM_addr_out),
		
		
		
		
		.CAM_xclk(CAM_xclk), 
		.CAM_pwdn(CAM_pwdn), 
		.CAM_reset(CAM_reset), 
		.CAM_PCLK(pclk), 
		.CAM_HREF(CAM_href), 
		.CAM_VSYNC(CAM_vsync),
		.CAM_px_data(CAM_px_data)
	);
	reg img_generate=0;
	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 1;
		pclk = 0;
		CAM_vsync = 1;
		CAM_href = 0;
     CAM_px_data=8'b11110000;
		//CAM_px_data = 8'b00000000;
   	// Wait 100 ns for global reset to finish
		#20;
		rst = 0;
		img_generate=1;

		
	end

	always #0.5 clk  = ~clk;
 	always #2 pclk  = ~pclk;
	
	
	reg [9:0]line_cnt=0;
	reg [9:0]row_cnt=0;
	
	parameter TAM_LINE=320;	// es 160x2 debido a que son dos pixeles de RGB
	parameter TAM_ROW=120;
	parameter BLACK_TAM_LINE=4;
	parameter BLACK_TAM_ROW=4;
	
	/*************************************************************************
			INICIO DE SIMULACION DE SE—ALES DE LA CAMARA 	
	**************************************************************************/
	/*simulaciÛn de contador de pixeles para  general Href y vsync*/
	initial forever  begin
	//CAM_px_data=~CAM_px_data;
		@(posedge pclk) begin
		if (img_generate==1) begin
			line_cnt=line_cnt+1;
			if (line_cnt >TAM_LINE-1+BLACK_TAM_LINE) begin
				line_cnt=0;
				row_cnt=row_cnt+1;
				if (row_cnt>TAM_ROW-1+BLACK_TAM_ROW) begin
					row_cnt=0;
					
				end
			end
		end
		end
	end

	/*simulaciÛn de la seÒal vsync generada por la camara*/	
	initial forever  begin
		@(posedge pclk) begin 
		if (img_generate==1) begin
			if (row_cnt==0)begin
				CAM_vsync  = 1;
				
			end 
			if (row_cnt==BLACK_TAM_ROW/2)begin
				CAM_vsync  = 0;
				
				
			end
		end
		end
	end
	
	/*simulaciÛn de la seÒal href generada por la camara*/	
	initial forever  begin
		@(negedge pclk) begin 
		if (img_generate==1) begin
		if (row_cnt>BLACK_TAM_ROW-1)begin
			if (line_cnt==0)begin
				CAM_href  = 1; 
				//CAM_px_data=~CAM_px_data;				
			

			end
		end
			if (line_cnt==TAM_LINE)begin
				CAM_href  = 0;
			end
		end
		end
	end
	
	    reg [1:0]cont2=0;
	  
    initial forever begin

        @(posedge pclk) begin
                if (cont2==0)begin
                    CAM_px_data=~CAM_px_data;
                end
//            if(cont2==0)begin
//                CAM_px_data=8'b11110000;
//            end
//            else if (cont2==1)begin
//                CAM_px_data=8'b11110000;
//            end
//            else if (cont2==2) begin
//                CAM_px_data=8'b00001111;
//            end
//            else begin
//                CAM_px_data=8'b00001111;
//            end 
            cont2=cont2+1;
        end
    end

	/*************************************************************************
			FIN SIMULACI“N DE SE—ALES DE LA CAMARA 	
	**************************************************************************/
	
	/*************************************************************************
			INICIO DE  GENERACION DE ARCHIVO test_vga	
	**************************************************************************/

	/* log para cargar de archivo*/
	integer f;
	initial begin
      f = $fopen("test_vga_g4.txt","w");
   end
	
	reg clk_w =0;
	always #1 clk_w  = ~clk_w;
	
	/* ecsritura de log para cargar se cargados en https://ericeastwood.com/lab/vga-simulator/*/
	initial forever begin
	@(posedge clk_w)
		$fwrite(f,"%0t ps: %b %b %b %b %b\n",$time,VGA_Hsync_n, VGA_Vsync_n, VGA_R[3:0],VGA_G[3:0],VGA_B[3:0]);
	end
	
endmodule
