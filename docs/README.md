## ELECTRÓNICA DIGITAL 1 2020 -2 UNIVERSIDAD NACIONAL DE COLOMBIA 
## TRABAJO 02- diseño y prueba del HDL para la cámara OV7670


#### Nombres:

- Fabian Steven Galindo Peña
- Jefersson Garzón Romero
- Juan Camilo Rojas Dávila 
- Sebastián Pérez Peñaloza

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

![ecuacion 640x480](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/Ecuacion%201%20ram.png)

Para el formato de 640x480 se necesitan 6 291 459 bits o 786 432 Bytes, lo que excede la capacidad de la FPGA. Analizando el espacio requerido para el formato 160x120 se obtuvo que:

![ecuacion 160x120](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/ecuacion%202%20ram.png)

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

![Entradas RGB](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/puertos%20vga.png)

Debido a que, la recepción de datos es por medio de dos bytes, de la forma 8’bXXXX_RRRR para el primero y 8’bGGGG_BBBB para el segundo, lo que se quiere, es escribir un registro de 12 bits con la información de los cuatro bits de cada color. De acuerdo al datasheet del módulo óptico OV7670:

![pixeles cam_read](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/RGB444%20data_sheet_camara.png)

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

Antes de empezar a hablar de la máquina de estados, es preciso definir los parámetros de control de la misma:

	reg [2:0] state=1;
	reg pas_vsync = 0;
	reg cont = 1'b0;
	reg [15:0] cont_href=16'h0000;
	reg pas_href= 0;
	reg [15:0] cont_pixel=16'h0000;
	reg [15:0] cont_pclk=16'h0000;
	
- **[2:0] state:** Estado, su valor va a decidir en qué parte de la máquina de estados nos vamos a encontrar.
- **pas_vsync:** valor anterior de vsync.
- **cont:** Contador de un sólo bit, que va a oscilar entre 0 y 1.
- **[15:0] cont_href:** Contador de href.
- **pas_href:** Valor anterior de href.
- **[15:0] cont_pixel:** Contador de píxeles.
- **[15:0] cont_pclk:** Contador del reloj de píxeles.

Lo último que es preciso realizar antes de hablar de la máquina de estados, es de la vuelta a valores iniciales, lo que es el ‘reset’, que devolverá nuestros registros a valores conocidos e iniciales:

    if (rst) begin
		
	DP_RAM_addr_in=0;
	cont_href[15:0]=16'h0000;
	state=1;pas_vsync=0;
			
    end else 

En esta parte, se puede evidenciar que, al tener el reset en 1 (high), pasará lo siguiente:

- DP_RAM_addr_in volverá a valer cero.
- cont_href volverá a cero.
- state será 1, lo cual nos posicionará al inicio de la máquina de estados.
- pas_vsync volverá a cero.

Todo esto funciona junto al reset general, lo cual nos posicionará al principio, previo a la primera captura de datos, por lo cual estos registros también volverán a sus respectivos estados iniciales. La máquina de estados funcionará de la siguiente manera:

![maquina_estados](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/maquina_estados.png)

Que, en el módulo también constará de 4 partes (casos), explicados a continuación:

#### Caso 1: Vuelta a cero (valores iniciales)

	1:		// Valores iniciales
		begin
			cont_href[15:0]=16'h0000;
			DP_RAM_addr_in=15'b1111_1111_1111_111;								
			if(pas_vsync && !CAM_VSYNC) begin
			    state=2;
			end
		end
			
Parecerá tonto hacer dos vueltas a cero en dos momentos consecutivos, pero esto trae una razón, no siempre va a suceder en dos momentos consecutivos, porque la vuelta a cero relativa al reset sucede únicamente cuando el pulsador correspondiente es presionado, de otra manera ese paso es saltado, además que, lo único que coincide en ambas puestas a cero, es la devolución de cont_href a cero, en este estado, cuando state=1, o bueno, a 3’b001, que es lo mismo, pasarán dos cosas, además de la devolución a cero de cont_href antes mencionada:

DP_RAM_addr_in se verá posicionado en su última posición, lo cual, al siguiente lo desbordara y volverá a cero, es un método efectivo, cuando se quiere iniciar en cero.

Únicamente, cuando pas_vsync esté en 1, y CAM_VSYNC en 0, se procederá al siguiente estado, en ese momento state=2 o bueno 3’b010, que es lo mismo.

#### Caso 2: Contador de href y primer registro

	2:		// Contador HREF
		begin
			if(!pas_href && CAM_HREF) begin
				cont_href = cont_href +1;
				cont_pixel = 0;
				state = 3;
				DP_RAM_data_in[11:8] = {CAM_px_data[3:0]};
				DP_RAM_regW = 0;
				cont = ~cont;
				cont_pclk = cont_pclk + 1;
					
			end 
			else if(CAM_VSYNC) 
				state=1;
			else if(0)
				state = 4;
			end
			
Al inicio veremos tres caminos a seguir:

pas_href=0 y CAM_HREF=1
	
Si se cumple esto, lo que se hará es incrementar en 1 cont_href, se volverá a cero cont_pixel, pasaremos al tercer estado con state=3 (o 3’b011, ya saben cómo funciona esto), a continuación escribimos los primeros (últimos, de [11:8]) bits correspondientes a los 4 bits de rojo, es decir los últimos (primeros, de [3:0]) bits del primer byte recibido, ponemos DP_RAM_regW en cero, lo que significa no enviar aún el registro de 12 bits, ya que aún no se ha escrito correctamente, cont cambiará de 0 a 1 o de 1 a 0 según el caso, como si de un tipo de clk se tratase, y finalmente aumentaremos en 1 cont_pclk.

CAM_VSYNC=1: Cuando sucede esto, significa que estamos al final del frame, por lo que volveremos a state=1 o lo mismo, volveremos al primer caso de la máquina de estados.

Photo_button=1: Cuando el pulsador correspondiente es presionado, pasaremos al estado 4, que, en pocas palabras (porque más adelante será explicado) congelaremos la imagen actual, (tomaremos la foto).

#### Caso 3: Captura de datos

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
				if(DP_RAM_addr_in < 19200|DP_RAM_addr_in==15'b1111_1111_1111_111) DP_RAM_addr_in = DP_RAM_addr_in + 1;
				cont_pixel = cont_pixel +1;
					
			end
			cont = ~cont;
				
		end else state=2;
	end

La razón de ser del presente módulo (cam_read) es este caso, en este estado, lo que se hace, es capturar los datos de los dos bytes, en nuestro registro de 12 bits, para completar el RGB 444 que necesitamos para darle color al pixel, empecemos:

Si CAM_HREF=1 empezamos la captura de datos, ¿recuerdan el contador cont que habíamos creado previamente y descrito su comportamiento?, bien, en este momento entendemos que, este contador de un bit nos es útil para contar dos “ciclos de reloj”, para saber cuándo estamos leyendo el primer byte, y cuándo el segundo byte. 

Cuando nuestro cont=0,  escribimos los primeros (últimos, del [11:8]) bits, correspondientes a los últimos (primeros, del [3:0]) bits del primer byte, los rojos, volvemos DP_RAM_regW a cero, porque no vamos a escribir (enviarlo) aún y aumentamos en uno el cont_pclk.

En caso que cont no sea 0, esto significa que es 1, porque es un registro de 1 bit, pues sencillo, significa que ya escribimos, bien sea en el paso inmediatamente anterior, o en el caso 2, en este momento escribimos los últimos (primeros, del [7:0]) bits, correspondientes a todo el segundo byte de datos de color, los 4 bits de verde, y los 4 bits de azul. A este momento de nuestra travesía, nuestro registro de 12 bits, correspondiente al RGB 444 del que hemos estado hablando desde hace un rato ya, estará listo, es perfecto, ya tiene los 4 bits del rojo, los 4 bits del verde y los 4 bits del azul, en perfecto orden, hacemos DP_RAM_regW 1 para avisar que ya está listo.

Finalmente, luego de avisar que ya tenemos todo listo en este registro, nos hacemos una pregunta, una muy importante, ¿Estamos al final de la pantalla?, ¿es este el último pixel del frame?, de eso hará juez la línea 80, en caso que no sea así, aumentamos en uno la dirección de entrada y finalmente incrementamos el contador de píxeles, porque siempre queremos saber dónde estamos.

Al terminar este proceso, bien sea de escribir el primero o el segundo byte de información en nuestro registro de 12 bits, negamos el valor de nuestro contador que funcionaba como reloj de un bit, para avisar que vamos a cambiar de byte.

Finalmente nos devolvemos a nuestro caso 2.

#### Caso 4: “Tomar foto”

	4:		// Mostrar imagen		
	begin
		DP_RAM_regW = 0;
			
		if(0)
				state = 1;
	end
	endcase

El objetivo del proyecto siempre fué el de hacer una cámara fotográfica, más o menos, lo que queremos, es lo de todas las cámaras, congelar un momento de la vida a modo de imagen, “detener el tiempo”, así sea en una pantalla, así sea por un momento, aunque no dure para siempre. Lo que queremos, es presenciar un instante en específico por un ratico, suena bastante filosófico, es casi poético. Al final, la fotografía es un arte, y detrás de ella, hay otro arte, la ingeniería aplicada, en nuestro caso, somos artistas, que nos dedicamos todo un semestre a buscar la manera de hacer nuestro arte, de “esculpir” esta fotografía. Has adivinado bien, nuestro cincel es la descripción de hardware, escupiendo estos módulos para encontrar los registros y las conexiones oportunas para cumplir con nuestro cometido.

El párrafo anterior, nos recuerda que, debemos buscar la manera de tomar nuestra fotografía, es bastante sencillo, llegar al caso 4 requiere haber presionado el pulsador Photo_button, esta acción, implicará directamente, que el registro de un bit DP_RAM_regW vuelva a cero, no seguirá enviando, ni leyendo nada más, ahí se va a detener, la imagen en pantalla se congelará, habremos tomado nuestra fotografía, habremos expresado nuestro arte.

Pero, sería muy tonto tomar sólo esa única fotografía, ¿cómo hacemos que el tiempo vuelva a transcurrir en nuestra pantalla?, ¿y si no me gustó la foto?, ¿si quiero capturar otro momento?, es sencillo, pero un poco triste a la vez, nuestra cámara no es capaz de generar una imagen como lo hace la del teléfono, no hay forma de capturar un pantallazo, como lo hacemos con la pantalla de nuestro PC, ese momento quedará únicamente, en nuestra memoria. Para que el tiempo vuelva a transcurrir en la pantalla, y regresar a la realidad, debemos presionar un pulsador, bautizado como Video_button, este, nos devolverá al primer caso, lo cual volverá a hacer que siga registrando y renovando con cada ciclo de reloj que pase, nuestro registro de 12 bits y el píxel en consecuencia. Ahora que lo pienso bien, deberían llamarse Dream_button y Reality_button, pero no es algo que cualquiera entendería tan sólo ver dos pulsadores en frente, que esto quede entre los dos, ¿vale?

#### Para finalizar

    	pas_vsync = CAM_VSYNC;
	end

    endmodule

¿No se nos olvida nada?, ah, si, se nos olvida una cosa, nunca explicamos cómo sabremos cuál era el estado anterior de VSYNC, en ninguna parte del HDL de arriba lo dice, si VSYNC nunca cambiase, nos sería imposible salir del primer caso. Entonces, por fuera de los case (de la máquina de estados), pero por cada ciclo de reloj, seguimos actualizando pas_vsync para siempre estar enterados del estado previo del mismo. De esta manera, podemos, satisfactoriamente, dar por finalizada la explicación del módulo cam_read y la máquina de estados.


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

![test cam](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/modulo_test_cam.png)

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

![convert addr](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/modulo%20convert%20addr.png)

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

![test bench](https://github.com/unal-edigital1-2020-1/wp2-simulacion-captura-grupo-04/blob/master/docs/Imagenes/modulo_test_cam_TB%7D.png)

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

