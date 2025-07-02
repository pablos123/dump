# Virtualización

## Por qué existen máquinas virtuales

El uso más frecuente es para aislar programas que brindan servicios. Muchas veces, dichos programas necesitan ambientes distintos (distintas versiones de librearías, SO, etc.) por lo cual es más fácil tener una computadora por programa.
Otro problema es que si ubicamos más de un servicio por computadora, un desperfecto en uno puede afectar el funcionamiento de otros sevicios.
La virtualización resuelve todos estos problemas: cada servicio puede ejecutarse en su propia máquina virtual, con el entorno que necesite y aislado de manera que si se cae un servicio, los otros no son afectados.
No solo los SO pueden virtualizarse sino tambien, por ejemplo, la memoria o las funciones de I/O.

### Tipos de virtualización

- Hipervisores (llamados tambien hipervisores tipo 1): son una capa fina de software que se activa sólo cuando el SO virtualizado quiere acceder al hardware. Por ejemplo: VMWare Workstation, Linux KVM, Microsoft Hyper-V.
- Emuladores (llamados tambien hipervisores tipo 2, o monitores de máquinas virtuales): son programas de usuario que emulan las instrucciones que acceden al hardware. Por ejemplo: VMWare Server, VirtualBox.

### Instrucciones sensibles

Son todas las instrucciones que acceden directamente al hardware e la computadora (fuera de la memoria y el ALU). Generalmente sólo puede ejecutarlas el SO pues requieren privilegios especiales.
Para poder virtualizar una computadora es necesario que el SO huésped se ejecute enteramente en modo usuario: en caso contrario apareceran todo tipo de conflictos (al intentar utilizar puertos, discos rígidos, interrupciones, etc). Cuando un SO quiere ejecutar una operación sensible, se debería saltar a modo kernel.

__La arquitectura de las computadoras 386 y sus derivadas no hacían esto hasta el 2005: algunas instrucciones sensibles simplemente se ignoraban si se ejecutaban en modo usuario. Por lo tanto, no podían usarse hipervisores para estas arquitecturas, sólo emuladores.__

## Hipervisores

Los hipervisores son básicamente sistemas operativos muy pequeños que ejecutan a los SO huéspedes como procesos de usuario.
Cuando un SO huésped quiere ejecutar una operación sensible, el hilo de ejecución pasa al hipervisor, que ejecuta la operación para el SO huésped, haciendo las traducciones que deba hacer.

## Emuladores (hipervisores de tipo 2)

Los emuladores como VirtualBox o VMWare Server no pueden confiar en que una instrucción sensible genere un salto a modo kernel, por lo cual deben emular el funcionamiento y los efectos de estas instrucciones.
Lo que se hace es la traducción de las partes de código que son sensibles, lo que se llama BT (binary translation).
La manera de hacerlo tradicionalmente es ir dividiendo el código a ejecutar en bloques.
Cada bloque es un conjunto de instrucciones que no son ni saltos ni instrucciones sensibles, y que terminan en alguna de esas instrucciones. Cada bloque se cachea y se ejecutan todas las instrucciones normalmente menos la última en modo usuario. La última instrucción se emula porque puede necesitar la intervención del emulador. Una vez que se emula la última instrucción, se sigue con la ejecución normal del próximo bloque.

> Uno pensaría que este tipo de virtualización es más lenta que la virtualización hecha por hipervisores, dado que hay que crear los bloques en tiempo de ejecución y emular las instrucciones en modo usuario. Sin embargo, este esquema de virtualización a veces es más rápido debido al cache de instrucciones ya que no se salta a modo kernel tan seguido.

## Paravirtualización

Es posible modificar el código fuente de muchos SO para que se ejecuten sobre un hipervisor específico. La idea es que el hipervisor provea una API para acceder al hardware simulado, y que el SO huésped sea modificado para hacer uso de esta API en vez de llamar a operaciones I/O. De esta manera se hace más sencillo escribir hipervisores, también se hace más rápida la ejecución del SO huésped.
__Un hipervisor de paravirtualización es prácticamente un microkernel que ejecuta SO huéspedes como procesos.__
