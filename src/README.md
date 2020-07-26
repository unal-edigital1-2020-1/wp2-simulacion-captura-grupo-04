## ELECTRÓNICA DIGITAL 1 2020 -2 UNIVERSIDAD NACIONAL DE COLOMBIA 
## TRABAJO 02- diseño y prueba del HDL para la cámara OV7670


#### Nombres:

- Fabian Steven Galindo Peña
- Jefersson Garzón Romero
- Juan Camilo Rojas Dávila 
- Sebastian Pérez Peñaloza

## Contenido

- Introducción
- Objetivos
- Cámara 
- Desarrollo de la simulación
  - Explicación funcionamiento general
  - Explicación módulo memoria buffer RAM
  - Explicación módulo captura de datos
  - Máquina de estados 
  - Explicación módulo VGA Driver
  - Explicación módulo test cam
  - Explicación módulo test bench
- Resultados simulación 
  - Historial de trabajo, progreso, errores y correcciones 
- Desarrollo de la implementación
  - Configuración de la cámara (arduino)
- Resultados de la implementación
- Conclusiones


## Introducción

Previo a esta entrega se había realizado el módulo de la memoria RAM teniendo en cuenta las especificaciones de la FPGA y de los datos que entrega la cámara. Con esto en mente para la entrega final se debe realizar el módulo de captura de datos que se encarga de tomar los datos de la cámara, adaptarlos y enviárselos al módulo buffer RAM en formato RGB444. Después se debe analizar el módulo test_cam.v y probar la funcionalidad del diseño utilizando un simulador. En el test_cam se deben usar los módulos ya creados de captura de datos, buffer RAM y el PLL (entregado por el profesor). Además al final se va a implementar usando la cámara digital OV7670.

## Desarrollo

