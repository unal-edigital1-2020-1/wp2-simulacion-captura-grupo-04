## ELECTRÓNICA DIGITAL 1 2020 -2 UNIVERSIDAD NACIONAL DE COLOMBIA 
## TRABAJO 02- diseño y prueba del HDL para la cámara OV7670


#### Nombres:

- Fabian Steven Galindo Peña
- Jefersson Garzón Romero
- Juan Camilo Rojas Dávila 
- Sebastian Pérez Peñaloza

## Contenido

* Introducción
* Objetivos
* Cámara 
* Desarrollo de la simulación
  * Explicación funcionamiento general
  * Explicación módulo memoria buffer RAM
  * Explicación módulo captura de datos
    * Máquina de estados 
  * Explicación módulo VGA Driver
  * Explicación módulo test cam
  * Explicación módulo test bench
* Resultados simulación 
  * Historial de trabajo, progreso, errores y correcciones 
* Desarrollo de la implementación
  * Configuración de la cámara (arduino)
* Resultados de la implementación
* Conclusiones


## Introducción

Previo a esta entrega se había realizado el módulo de la memoria RAM teniendo en cuenta las especificaciones de la FPGA y de los datos que entrega la cámara. Con esto en mente para la entrega final se debe realizar el módulo de captura de datos que se encarga de tomar los datos de la cámara, adaptarlos y enviárselos al módulo buffer RAM en formato RGB444. Después se debe analizar el módulo test_cam.v y probar la funcionalidad del diseño utilizando un simulador. En el test_cam se deben usar los módulos ya creados de captura de datos, buffer RAM y el PLL (entregado por el profesor). Además al final se va a implementar usando la cámara digital OV7670.

## Objetivos

* Entender el funcionamiento de los distintos módulos a implementar.
* Desarrollar y corregir los módulos necesarios para el funcionamiento del proyecto.
* Desarrollar habilidades de simulación y diseño de hardware.
* Probar el diseño con una cámara de verdad.

## Desarrollo de la simulación

### Explicación funcionamiento general

Como se puede ver en la imagen, se deben recibir los datos y señales que vienen de la cámara. Estos se procesan en el test cam que consta de 4 módulos distintos. El primero es el PLL que da relojes de distintas frecuencias (25 MHz y 24 MHz). El siguiente sería la captura de datos que recibe la información de la cámara, crea los registros con pixeles en formato RGB444 y los envía a una dirección específica de la memoria buffer RAM. La memoria buffer RAM almacena los datos en un registro de 12 bits de ancho (tamaño del píxel) con capacidad de almacenar 19200 pixeles en las direcciones indicadas y además recibe direcciones de salida desde el VGA driver. El VGA driver genera la imagen que se va a mostrar en la pantalla teniendo en cuenta la posición en la que debe ir cada píxel guardado en la memoria buffer RAM y rellenando con color negro los sitios en donde no va la imagen, pues la imagen es de 160x120 y la pantalla es de 640x480.

### Explicación módulo memoria buffer RAM

Para comenzar el diseño del módulo de la memoria buffer RAM primero se tiene que entender las capacidades de la FPGA. La memoria de la FPGA tiene una capacidad de 4860 kbits, esto equivale a 607,5 kBytes. La idea es que la memoria RAM ocupe como máximo 50% de este espacio entonces la memoria máxima a utilizar sería de 303,75 kBytes o 311 040 Bytes. El formato a utilizar es el RGB444 pues es el que se necesita para proyectar el resultado en la pantalla que vamos a utilizar. El tamaño de imagen es el más pequeño que entrega la cámara que es 160x120. Esta cámara puede entregar una imagen de 640x480 pero ocupa más espacio del deseado pues: 



Para el formato de 640x480 se necesitan 6 291 459 bits o 786 432 Bytes, lo que excede la capacidad de la FPGA. Analizando el espacio requerido para el formato 160x120 se obtuvo que:




Para el formato de 160x120 se necesitan 393 216 bits o 49140,75 Bytes. Con este formato se utiliza menos memoria de la disponible en la FPGA asegurando que va a funcionar. Ya con el espacio definido se procede a diseñar el módulo:

    input  clk_w, 
    input  [AW-1: 0] addr_in, 
    input  [DW-1: 0] data_in,
    input  regwrite, 
    input  clk_r, 
    input [AW-1: 0] addr_out,
    output reg [DW-1: 0] data_out

- **AW:** Define el número de direcciones posibles. 2 elevado AW es la cantidad de direcciones posibles y en este caso AW es igual a 15 por los cálculos hechos previamente. 
- **DW:** Define el tamaño de los datos que van a entrar a la memoria. En este caso este parámetro es igual a 12 por el formato de píxel escogido.
- **clk_w:** Es el reloj que sincroniza la escritura de datos en la memoria buffer RAM.
- **addr_in:** Es la dirección de entrada del dato, define en qué espacio de la memoria se va a guardar. Esta dirección la define el módulo de captura de datos.
- **data_in:** Es el dato que entra a la memoria. Este fue procesado previamente en el módulo de captura de datos.
- **regwrite:** Es el registro que indica si ya se puede hacer la escritura de datos en la memoria o no.
- **clk_r:** Es el reloj que sincroniza la lectura de los datos guardados en la memoria.
- **addr_out:** Es la dirección en el registro del dato que va a salir hacia el VGA Driver.
- **data_out:** Es el dato que sale de la memoria hacia el VGA Driver.

    localparam NPOS = 2 ** AW;
    param imagesize=160*120;
    reg [DW-1: 0] ram [0: NPOS-1]; 
    
Después de definir las entradas y las salidas se procede a crear el espacio donde se van a guardar los datos. Para esto se define el número de posiciones que tendrá la memoria, en este caso 2 elevado AW. Después se crea el registro de 12 bits de largo por el número de posiciones posibles.

    always @(posedge clk_w) begin 
        if (regwrite == 1) 
            ram[addr_in] <= data_in;
    end

Para la escritura de datos en la memoria se usan los tiempos del clk_w para revisar si ya es momento de guardar los datos o no. Si es el momento entonces se procede a asignarle el dato de entrada al espacio en la memoria definido por la dirección de entrada.

    always @(*) begin 
        data_out <= ram[addr_out]; 
    end

Para la lectura de los datos guardados se espera a que haya un cambio en la dirección de salida que se pide para poder entregar el dato. 

    initial begin
        $readmemh(imageFILE, ram);
        ram[imagesize] = 12'b000000000000;  
    end

Para iniciar la memoria buffer RAM inicialmente se lee un archivo .men que contiene los datos predeterminados de 19200 pixeles en formato RGB444 y a la última posición de la memoria se le asignan 0s.

### Explicación módulo captura de datos

Debe existir un módulo encargado de realizar la captura de datos y escribir un registro del tamaño deseado, en nuestro caso RGB 444, este formato es el elegido, debido a que, por medio y gracias a este, trabaja la conexión de video VGA, en otras palabras RGB de 12 bits, 4 por cada color.



Debido a que, la recepción de datos es por medio de dos bytes, de la forma 8’bXXXX_RRRR para el primero y 8’bGGGG_BBBB para el segundo, lo que se quiere, es escribir un registro de 12 bits con la información de los cuatro bits de cada color. De acuerdo al datasheet del módulo óptico OV7670:



Se quiere que se tomen los bits 0, 1, 2 y 3 del primer byte, y todos los del segundo byte. Para esta tarea, es que existe el módulo cam_read.v. Inicialmente, se deben declarar las entradas y salidas del módulo, por medio de las cuales se va a comunicar con los demás.

    parameter AW = 15 
		)(
		input rst,
		input CAM_PCLK,
		input CAM_VSYNC,
		input CAM_HREF,
		input [7:0] CAM_px_data,
    //		input Photo_button,
    //		input Video_button,

		output reg [AW-1:0] DP_RAM_addr_in = 0,
		output reg [11:0] DP_RAM_data_in = 0,
		output reg DP_RAM_regW = 0

Parámetro:

- **AW:** Tamaño (en bits) del registro de dirección del píxel.

Entradas (Inputs):

- **rst**: Reset
- **CAM_PCLK:** Señal del reloj de píxeles (Pixel Clock)
- **CAM_VSYNC:** Señal de sincronización vertical, emitida una vez al finalizar el dibujo de cada frame.
- **CAM_HREF:** Señal de referencia horizontal, emitida una vez al finalizar el dibujo de cada línea del frame.
- **[7:0] CAM_px_data:** Registro de 8 bits (1 byte), referido a cada byte enviado por la cámara, explicado al inicio de este apartado.
- **Photo_button:** Señal binaria generada por un pulsador físico, para congelar la imagen registrada por el sensor óptico. (Tomar fotografía)
- **Video_button:** Señal binaria generada por un pulsador físico, para regresar al flujo de fotogramas normal, registrado por el sensor óptico. (Volver a vídeo)

Salidas (Outputs):
	
- **[AW-1:0] DP_RAM_addr_in:** Registro de ‘AW’ bits relativo a la dirección del píxel dibujado.
- **[11:0] DP_RAM_data_in:** Registro de 12 bits relativo a la información específica de cada píxel dibujado en pantalla.
- **DP_RAM_regW:** Registro de 1 bit encargado de avisar el momento en que la información de color de cada píxel ([11:0] DP_RAM_data_in) ya ha sido almacenada correctamente, para su envío.

### Explicación módulo VGA Driver

    (
        //entradas 
	    input rst,
	    input clk, 				// 25MHz  para 60 hz de 640x480
	    input  [11:0] pixelIn, 	// entrada del valor de color  pixel 
	    //salidas
	    output  [11:0] pixelOut, // salida del valor pixel a la VGA 
	    output  Hsync_n,		// señal de sincronizacion en horizontal negada
	    output  Vsync_n,		// señal de sincronizacion en vertical negada 
	    output  [9:0] posX, 	// posicion en horizontal del pixel siguiente
	    output  [9:0] posY 		// posicion en vertical  del pixel siguiente
    );
    
    localparam SCREEN_X = 640; 	// tamaño de la pantalla visible en horizontal 
    localparam FRONT_PORCH_X =16;  
    localparam SYNC_PULSE_X = 96;
    localparam BACK_PORCH_X = 48; //28
    localparam TOTAL_SCREEN_X = SCREEN_X+FRONT_PORCH_X+SYNC_PULSE_X+BACK_PORCH_X; 	// total pixel pantalla en horizontal 
    
    
    localparam SCREEN_Y = 480; 	// tamaño de la pantalla visible en Vertical 
    localparam FRONT_PORCH_Y =10;  
    localparam SYNC_PULSE_Y = 2;
    localparam BACK_PORCH_Y = 33;
    localparam TOTAL_SCREEN_Y = SCREEN_Y+FRONT_PORCH_Y+SYNC_PULSE_Y+BACK_PORCH_Y; 	

- **rst:** Reset
- **clk:** Reloj de lectura de la memoria RAM - 25MHz, para 60 hz de 640x480
- **pixelin[11:0]:** Entrada valor del color del pixel de la RAM
- **pixelOut[11:0]:** Salida del Valor del pixel a la VGA.
- **Hsync_n:** señal de sincronización en horizontal negada.
- **Vsync_n:** señal de sincronización en vertical negada.
- **posX[9:0]:** posición en horizontal del pixel siguiente.
- **posY[9:0]:** posición en vertical del pixel siguiente.

Calculamos el tamaño de la pantalla que vamos a usar teniendo en cuenta la zona negra que va a quedar por la resolución empleada

    reg  [9:0] countX;
    reg  [9:0] countY;
    
    assign posX = countX;
    assign posY = countY;

- **CountX:** Contador de Píxeles Horizontal 
- **CountY:** Contador de píxeles vertical 

Con el fin de determinar la dirección en que está visualizando el pixel.  Se asigna como posición de inicio en el primer ciclo del reloj los valores de 640 (PosX),  480(PosY) de esta manera la toma de datos es mas rapida 

    assign pixelOut = (countX<SCREEN_X) ? (pixelIn) : (12'b000000000000) ;
    
    assign Hsync_n = ~((countX>=SCREEN_X+FRONT_PORCH_X) && (countX<SCREEN_X+SYNC_PULSE_X+FRONT_PORCH_X)); 
    assign Vsync_n = ~((countY>=SCREEN_Y+FRONT_PORCH_Y) && (countY<SCREEN_Y+FRONT_PORCH_Y+SYNC_PULSE_Y));

Asignando un valor al dato de la salida, tenemos que si countX es menor a 640 se toma el valor del dato pixelIN de otra forma se asignan ceros que representan el color negro. Además Hsync_n Vsync_n: Dependen de countX y countY. 

    always @(posedge clk) begin
	    if (rst) begin
		    countX <= (SCREEN_X+FRONT_PORCH_X-1);
		    countY <= (SCREEN_Y+FRONT_PORCH_Y-1);
	    end
	    else begin 
	        if (countX >= (TOTAL_SCREEN_X-1)) begin
		      countX <= 0;
		      if (countY >= (TOTAL_SCREEN_Y-1)) begin
		          countY <= 0;
		end 
		    else begin
		        countY <= countY + 1;
		    end
		end 
		else begin
		    countX <= countX + 1;
		    countY <= countY;
		end
	    end
    end

Realizando el conteo de las posiciones en X y Y en las variables dependientes Hsync Vsync se establece una sincronización con los flancos de subida del reloj, es decir que si los contadores son mayores  o iguales al tamaño de la pantalla -1 los contadores se reinician en Cero (esquina superior izquierda) de lo contrario su valor aumenta +1 pixel de salida.

### Explicación módulo test cam

    input wire clk,           // board clock: 100 MHz 
    input wire rst,    // reset button
    
	// VGA input/output  
    output wire VGA_Hsync_n,  // horizontal sync output
    output wire VGA_Vsync_n,  // vertical sync output
    output wire [3:0] VGA_R,	// 4-bit VGA red output
    output wire [3:0] VGA_G,  // 4-bit VGA green output
    output wire [3:0] VGA_B,  // 4-bit VGA blue output
	

	output wire clk25M,
	//cables de revison de los lectura y escritura de datos
	output wire [14:0]  DP_RAM_addr_in,
	output wire [11:0] DP_RAM_data_in,
	output wire DP_RAM_regW,
	output reg [14:0] DP_RAM_addr_out,
	output wire [11:0] data_mem,
	
	//CAMARA input/output
	
	output wire CAM_xclk,		// System  clock imput
	output wire CAM_pwdn,		// power down mode 
	output wire CAM_reset,		// clear all registers of cam
	
	input wire CAM_PCLK,				// Sennal PCLK de la camara
	input wire CAM_HREF,				// Sennal HREF de la camara
	input wire CAM_VSYNC,				// Sennal VSYNC de la camara
	input wire [7:0] CAM_px_data     // Bit n de los datos del pixel

Entradas y salidas: Las entradas y salidas del test_cam son las entradas, salidas y conexiones internas de los módulos que se utilizan. Las entradas son señales de la cámara ya sea física o de simulación, mientras que las salidas son señales para controlar la cámara y el control y envío de  datos a la pantalla VGA.  Se agregaron salidas de conexiones internas haciendo la revisión de algunos registros para tener información en la simulación y confirmar el funcionamiento.

En el test cam se instancian los módulos necesarios para su funcionamiento de la siguiente manera (NOTA: entradas y salidas explicadas anteriormente en cada módulo):

clk_100MHZ_to_25M_24M:

    assign clk100M =clk;   
    clk_100MHZ_to_25M_24M pll(
      .CLK_IN1(clk),
      .CLK_OUT1(clk25M),
      .CLK_OUT2(clk24M),
      .RESET(rst)
      //.LOCKED()
    );
    
Cam_read:

    cam_read Camera_Read(
		// Entradas
		.rst(rst),
		.CAM_PCLK(CAM_PCLK),
		.CAM_VSYNC(CAM_VSYNC),
		.CAM_HREF(CAM_HREF),
		.CAM_px_data(CAM_px_data),
    //		.Photo_button(Photo_button),
    //		.Video_button(Video_button),
		
		// Salidas
		.DP_RAM_addr_in(DP_RAM_addr_in),
		.DP_RAM_data_in(DP_RAM_data_in),
		.DP_RAM_regW(DP_RAM_regW)
    );
    
buffer_ram_dp:

    buffer_ram_dp #(AW,DW)
	DP_RAM(  
	//entradas
	
	.clk_w(CAM_PCLK), 
	.addr_in(DP_RAM_addr_in), 
	.data_in(DP_RAM_data_in),
	.regwrite(DP_RAM_regW), 
	.clk_r(clk25M), 
	.addr_out(DP_RAM_addr_out),
	//.reset(rst)
	//salidas
	.data_out(data_mem)
	
    );

VGA_Driver640x480:

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
    
Módulo interno convert addr:

    always @ (VGA_posX, VGA_posY) begin
		if ((VGA_posX>CAM_SCREEN_X-1) |(VGA_posY>CAM_SCREEN_Y-1))
			DP_RAM_addr_out=160*120;
		else
			DP_RAM_addr_out=VGA_posX+VGA_posY*CAM_SCREEN_X;//DP_RAM_addr_out=CAM_SCREEN_X*CAM_SCREEN_Y;
    end

Entradas: VGA_posX, VGA_posY.
Salida: DP_RAM_addr_out 
Dependiendo de la posición horizontal y vertical de la VGA calcula la dirección de salida que se le envía al buffer para pedir el dato guardado en esa dirección. Si está por fuera de la zona de adquisición de la cámara le envia la direccion del pixel maximo + 1, cuyo pixel esta definido el modulo bufer_ram.v con el color negro, generando asi un color negro por fuera de la zona de adquisicion de la camara que es 120x160.

Se divide el pixel de salida data RGB444 en 3 partes VGA_R, VGA_G y VGA_B rojo, verde y azul respectivamente, que son las señales que va a leer la VGA por cada pixel.

    assign VGA_R = {data_RGB444[11:8]};
    assign VGA_G = {data_RGB444[7:4]};
    assign VGA_B = {data_RGB444[3:0]};

Se le asignan las salidas del control de la cámara.

    assign CAM_xclk = clk24M;
    assign CAM_pwdn = 0;			// power down mode 
    assign CAM_reset = 0;
    
### Explicación módulo test bench

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

    wire clk25M;
	
	//cables de revison de los lectura y escritura de datos
    wire [11:0] data_mem;
    wire [14:0] DP_RAM_addr_out;
    wire DP_RAM_regW;
	wire [14:0] DP_RAM_addr_in;
	wire [11:0] DP_RAM_data_in;

En el test bench primero se definen las señales necesarias para instanciar el test cam. Entre estas están las de entrada, salida y otras para poder visualizar lo que está pasando dentro del test cam.

    reg img_generate=0;
	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 1;
		pclk = 0;
		CAM_vsync = 1;
		CAM_href = 0;
        CAM_px_data=8'b00001111;
		//CAM_px_data = 8'b00000000;
		#20;
		rst = 0;
		img_generate=1;	
	end

	always #0.5 clk  = ~clk;
 	always #2 pclk  = ~pclk;
	
	
	reg [8:0]line_cnt=0;
	reg [6:0]row_cnt=0;
	
	parameter TAM_LINE=320;	// es 160x2 debido a que son dos pixeles de RGB
	parameter TAM_ROW=120;
	parameter BLACK_TAM_LINE=4;
	parameter BLACK_TAM_ROW=4;
	
Después se inicializan las señales de entrada al test cam y se definen unos parámetros para poder comenzar con la simulación. Además se crean unos contadores para poder controlar la simulación de las señales de la cámara.

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
	
Lo primero es simular los contadores que van a llevar la cuenta de la línea en la que se está y la fila en la que se está. Esta cuenta depende de los parámetros definidos al inicializar las señales de entrada.

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
	
La primera señal que se simula es vsync la cual depende del contador de filas. Esta señal comienza siendo 1 y apenas el contador de filas sea igual a 2 esta va a ser 0 y no va a volver a ser 0 hasta que el contador vuelva a iniciar. Y todos estos cambios sólo son posibles mientras se está generando la imagen.

	initial forever  begin
	   @(negedge pclk) begin 
	       if (img_generate==1) begin
	           if (row_cnt>BLACK_TAM_ROW-1)begin
	               if (line_cnt==0)begin
	                   CAM_href  = 1; 
	                   //CAM_px_data=~CAM_px_data;
	               end
	           end
	           if  (line_cnt==TAM_LINE)begin 
	               CAM_href  = 0;
		       end
		   end
	   end
	end

Inicialmente href es igual a 0 y para simular su comportamiento se usa el contador de líneas y el de filas. Cuando el contador de filas sea mayor a 3 y además el de líneas sea 0 href va a cambiar a 1. Cuando el contador de líneas sea igual al tamaño de línea href volverá a ser 0. Todo esto mientras se esté generando la imagen.

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

Finalmente se usan las salidas del test cam para crear un archivo .txt en un formato especial para que lo lea el simulador de vga online para poder visualizar los resultados obtenidos.

