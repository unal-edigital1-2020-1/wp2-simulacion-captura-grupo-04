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

#### Explicación funcionamiento general

Como se puede ver en la imagen, se deben recibir los datos y señales que vienen de la cámara. Estos se procesan en el test cam que consta de 4 módulos distintos. El primero es el PLL que da relojes de distintas frecuencias (25 MHz y 24 MHz). El siguiente sería la captura de datos que recibe la información de la cámara, crea los registros con pixeles en formato RGB444 y los envía a una dirección específica de la memoria buffer RAM. La memoria buffer RAM almacena los datos en un registro de 12 bits de ancho (tamaño del píxel) con capacidad de almacenar 19200 pixeles en las direcciones indicadas y además recibe direcciones de salida desde el VGA driver. El VGA driver genera la imagen que se va a mostrar en la pantalla teniendo en cuenta la posición en la que debe ir cada píxel guardado en la memoria buffer RAM y rellenando con color negro los sitios en donde no va la imagen, pues la imagen es de 160x120 y la pantalla es de 640x480.

#### Explicación módulo memoria buffer RAM

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

#### Explicación módulo captura de datos



#### Explicación módulo VGA Driver

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

