# Memoria

## Funciones y operaciones

**El único espacio de almacenamiento que el procesador puede utilizar directamente, más allá de los registros (que son de capacidad demasiado limitada) es la memoria física**.
**Todas las arquitecturas de procesador tienen instrucciones para interactuar con la memoria, pero ninguna tiene instrucciones para hacerlo con medios _persistentes_ de almacenamiento**.
Tipos de almacenamiento:

- Almacenamiento primario: memoria
- Almacenamiento secundario: discos u otros medios de almacenamiento persistente.
  Todos los programas deben cargarse a la memoria del sistema antes de ser utlizados.

## Espacio de direccionamiento

La memoria está estructurada como un arreglo direccionable de bytes. Esto es, al solicitar el contenido de una dirección específica de memoria, el hardware entregará un byte (8 bits), y no menos. Si se requiere hacer una operación sobre bits específicos, se deberá solicitar y almacenar bytes enteros. Un procesador que soporta un **espacio de direccionamiento** de 16 bits puede referirse directamente a hasta $2^{16}$ bytes, etc. Hoy en día, los procesadores dominantes son de 32 o 64 bits. En el caso de los procesadores de 32, sus registros pueden referenciar hasta 4 GB de RAM. Uno de 64 bits podría dereccionar 16 Exabytes. Esto no tiene sentido y por lo gral los chips están limitados a entre $2^{40}$ y $2^{48}$.

## MMU: unidad de manejo de memoria

Con la introducción de sistemas multitarea, es decir, donde se tienen dos o más programas ejecutandose, apareció la necesidad de tener más de un programa cargado en memoria. Fue necesario abstraer el espacio de almacenamiento para dar la ilusión de contar con más memoria de la que está directamente disponible. **Con asistencia del hardware, es posible configurar un espacio lineal contiguo para cada proceso y para el mismo sistema operativo que se proyecta a memoria física y a un almacenamiento secundario.**
La MMU cubre estas necesidades, y es también la encargada de verificar que un proceso no tenga acceso a leer o modificar los datos de otros.

> Si el sistema operativo tuviera que verificar cada una de las intrucciones ejecutadas por un programa para evitar errores en el acceso a la memoria, la penalización en velocidad sería demasiado severa.

Una primera aproximación a la protección de acceso se implementa usando un _registro base_ y un _registro límite_: si la arquitectura ofrece dos registros dle procesador que sólo pueden ser modificados por el SO (el hardware define la modificación de dichos registros como una operación para ejecutar en _modo supervisor_), la MMU puede comparar sin penalidad cada acceso a memoria para verificar que esté en el rango permitido.

!

## Caché

Cuando el procesador solicita el contenido de una dirección de memoria y esta no está aún disponible, tiene que detener su ejecución (_stall_) hasta que los datos estén disponibles. **El CPU no puede, a diferencia del sistema operativo, "congelar" todo y guardar el estado para atender otro proceso: para el procesador, la lista de instruccinoes a ejecutar es estrictamente secuecial, y todo tiempo que requiere esperar una transferencia de datos es tiempo perdido.**
La respues para reducir esa espera es la **memoria caché**. Esta es una memoria de alta velocidad, situada entre la memoria principal y el procesador propiamente, que guarda copias de las páginas que van siendo accesadas, partiendo del **principio de la localidad de referencia**:

- **Localidad temporal**: es probable que un recurso que fue empleado recientemente vuelva a emplearse en un futuro cercano.
- **Localidad espacial**: la probabilidad de que un recurso aún no requerido sea accesado es mucho mayor si fue requerido algún recurso cercano.
- **Localidad secuencial**: un recurso, y muy particularmente la memoria, tiende a ser requerido de forma secuencial.

Aplicando el concepto de localidad de referencia, cuando el procesador solicita al hardware determinada dirección de memoria, el hardware no solo transfiere a la memoria caché el byte o palabra solicitado, sino que transfiere un bloque a página completo.

## Espacio en memoria de un proceso

!

## Resolución de direcciones

Un programa compilado no emplea nombres sibólicos para las variables o funciones que llama. (No hay diferencia real entre la dirección que ocupa una variable o código ejecutable. La diferencia se establece por el uso que se dé a la referencia de memoria.) El compilador al convertir el programa a lenguaje de máquina, las sustituye por la dirección en memoria donde se encuentra la variable o la función.
En los sistemas actuales, los procesos requieren coexistir con otros, para lo cual las direcciones indicadas en el _texto_ del programa pueden requerir ser traducidas al **lugar relativo al sitio de inicio del proceso en memoria**, esto es, las direcciones son resueltas o traducidas. Las estrategias para lograr esto son:

- **En tiempo de compilación**: el texto del programa tiene la dirección absoluta de las variables y funciones. Ya no se usa, se ve en sistemas embebidos.
- **En tiempo de carga**: al cargarse a memoria el programa y antes de iniciar su ejecución, el cargar (componente del SO) actualiza las referencias a memoria dentro del texto para que apunten correctamente.
- **En tiempo de ejecución**: el programa nunca hace referencia a una ubicación absoluta de memoria, sino que lo hace siempre relativo a una _base_ y un _desplazamiento (offset)_. Esto permite que el proceso sea incluso **reubicado en la memoria** mientras está siendo ejecutado, sin sufrir cambios (**requiere una MMU**).

!

# Asignación de memoria continua

Al nacer los primeros sistemas operativos multitarea, se hizo necesario resolver cómo asignar el espacio en memoria a diferentes procesos.

## Partición de la memoria

Se puede asignar a cada programa a ser ejecutado un bloque _contiguo_ de memoria de un tamaño fijo. El sistema operativo emplearía una región específica de la memoria del sistema (típicamente, una región baja hacia arriba) y luego el sistema asigna espacio a cada uno de los procesos. Si la arquitectura en cuestión permite **limitar los segmentos disponibles** a cada uno de los procesos, esto sería suficiente para alojar en memoria varios procesos y evitar que interfieran entre sí. Desde la perspectiva del SO, cada uno de los espacios asignados a un proceso es una _partición_. Al cargar un programa el SO calcula cuánta memoria va a requerir a lo largo de su vida prevista.

## Fragmentación

Es un fenómeno que se manifiesta a medida que los pocesos terminan su ejecución, y el sistema operativo libera la memoria asignada a cada uno de ellos. Comienzan a aparecer regiones de memoria disponible, interrumpidas por refiones de memoria usada.
Si la computadora no tiene hardware específico que permita que los procesos resuelvan sus direcciones en tiempo de ejecución, el SO no puede reasigna los bloques existentes.
Al crear un nuevo proceso, el SO tiene tres estrategias para asignar bloques disponibles:

- **Primer ajuste**: el sistema toma el primer bloque con el tamaño suficiente para alojar el nuevo proceso.
  - Es muy simple de implementar.
  - Muy rápida ejecución.
  - Desperdicia memoria.
- **Mejor ajuste**: el sistema busca entre todos los bloques disponibles cuál es el que mejor se ajusta al tamaó requerido por el nuevo proceso.
  - Requiere una revisión completa de la lista de bloques.
  - Permite que los bloques remanentes sean tan pequeños como sea posible.
- **Peor ajuste**: el sistema busca cuál es el bloque más grande disponible, y se lo asigna al nuevo proceso.
  - Puede llegar a ser más rápida que 'primer ajuste'.
  - Balancea el tamaño de los bloques remanentes.
    La _fragmentación externa_ se produce cuando hay muchos bloques libres entre bloques asignados a procesos; la _fragmentación interna_ se refiere a la cantidad de memoria dentro de un bloque que nunca se usará.

> Por cada N bloques asignados, se perderán del orden de 0.5N bloques por fragmentación interna y externa.

## Compactación

Un resultado de la fragmentación es que el espacio total libre de memoria puede ser mucho mayor que lo que requiere un nuevo proceso, pero al estar _fragmentada_ en muchos bloques, éste no encontrará una partición contigua donde ser cargado. Cuando el SO comience a detectar un alto índice de fragmentación, puede lanza una operación de **compresión** (eso solo si los procesos emplean resolución de direcciones en tiempo de ejecución). La compactación **tiene un costo alto, involucra mover asi la totalidad de la memoria (probablemente más de una vez por bloque)**.

## Intercambio (swap) con almacenamiento secundario

Algunos sistemas utilizan _swap_ entre la memoria primaria y secundaria. El SO puede comprometer más espacio de memoria del que tiene físicamente disponible. Cuando la memoria se acaba, el sistema suspende un proceso (usualmente un 'bloqueado') y almacena una copia de su imagen en memoria en el almacenamieto secundario para luego poder restaurarlo.
Consideraciones antes de suspender:

- si el proceso tiene pendiente alguna I/O que debe ser copiado en el espacio de memoria. Una solución es que todas las operaciones se realicen únicamente a _buffers_ en el espacio del SO y luego éste transfiera el resultado al espacio de memoria del proceso suspendido.

Esta técnica ya no es muy utilizada, dado el tamaño de los procesos y la lentitud de acceso al disco.

# Segmentación

La segmentación es un concepto que se aplica directamente a la arquitectura del procesador. Permite separar las regiones de la memoria _lineal_ en _segmentos_, cada uno de los cuales puede tener diferentes permisos de acceso. La segmentación ayuda a incrementar la _modularidad_ de un programa: es muy común que las biblitecas _ligadas dinámicamente_ estén representadas en segmentos independientes.
Un código compilado para procesadores que implementen segmentación siempre generará referencias a la memoria en un espacio _segmentado_. Este tipo de referencias se denominan direcciones lógicas y están formadas por un _selector_ de segmento y un _desplazamiento_ dentro del segmento. La MMU debe tomar el selector, y usando alguna estructura de datos, obtiene la dirección base, el tamaño del segmento y sus atributos de protección. Luego toma la dirección base le suma el desplazamiento y obtiene la **dirección física**.

!

## Permisos

La segmentación también permite distinguir niveles de acceso a la memoria: para que un proceso pueda efectuar llamadas al sistema, debe tener acceso a determinadas estructuras compartidas del núcleo. Su acceso requiere que el procesador esté ejecutando en _modo supervisor_.

!

En caso de haber más de una excepción, como se observa en la solicitud
de lectura de la dirección 3-132, el sistema debe reaccionar primero a la
más severa: si como resultado de esa solicitud iniciara el proceso de carga
del segmento, sólo para abortar la ejecución del proceso al detectarse la
violación de tipo de acceso, sería un desperdicio injustificado de recursos.

### Rendimiento

Por ejemplo si se tiene un segmento de texto y su acceso es de sólo lectura, una vez que éste fue copiado ya al disco, no hace falta a volver a hacerlo, basta marcarlo como no presente y si se ocasiona un fallo por página faltante lo vuelvo a traer.

# Paginación

La fragmentación externa y, por lo tanto, la necesidad de **compactación** pueden evitarse por completo empleando la **paginación**. Esta consiste en dividir cada proceso en varios bloques de tamaño fijo (**más pequeños que lo segmentos**) llamados páginas. Esto requiere de mayor soporte por parte del hardware y mayor información relacionada a cada uno de los procesos: no basta sólo con indicar dónde inicia y termina el área de memoria de cada proceso, se debe establecer un mapeo entre la ubicación real (física) y la presentada a cada uno de los procesos (lógica). **La memoria se presentará a cada proceso como si fuera de su uso exclusivo**
La memoria fśica se divide en una serie de _marcos (frames)_, todos ellos del mismo tamaño, y el espacio para cada proceso se divide en una serie de _páginas (pages)_, **del mismo tamaño que los marcos**. La MMU se encarga del mapeo entre páginas y marcos mediante _tablas de páginas_.
Características:

- Las direcciones que maneja el CPU ya no son presentadas de forma absoluta. Los bits de las direcciones se separan en un **identificador de página** y un **desplazamiento**.
- El tamaño de los marcos (y, por lo tanto, las páginas) **debe ser una potencia de dos**, para que la MMU pueda discernir fácilmente la porción de una dirección de memoria que refiere a la página del desplazamiento.

## Tamaño de página

Si bien la fragmentación externa se resuelve al emplear paginación, el problema de la fragmentación interna persiste. Si tomara como estrategia usar páginas muy pequeñas, la sobrecarga administrativa en que se incurre por gestionar demasiadas páginas pequeñas se vuelve una limitante en sentido opuesto:

- Las transferencias entre unidades de disco y memoria son mucho más eficientes si pueden mantenerse como recorridos continuos. El controlador de disco puede responder a solicitudes de acceso directo a memoria (DMA) siempre que tanto los fragmentos en disco como en memoria sean continuos; fragmentar la memoria demasiado jugaría en contra de la eficiencia de estas solicitudes.
- El bloque de control de proceso (PCB) incluye la información de memoria. Entre más páginas tenga un proceso (aunque éstas fueran muy pequeñas), más grande es su PCB, y más información requerirá intercambiar en un cambio de contexto.

Esto nos dice que se deben mantener las páginas grandes.

## Memoria compartida

Hay muchos escenarios en que diferentes procesos pueden beneficiarse de compartir áreas de su memoria:

- **IPC, inter process communication** en el cual dos o más procesos pueden intercambiar estructuras de datos complejas sin incurrir en el costo de copiado que implicaría copiarlas por medio del SO.
- **Compartir código**: si un mismo programa es ejecutado varias veces, y dicho programa no emplea mecanismos de código auto-modificable, no tiene sentido que las páginas en que se representa cada una de dichas instancias ocupen un marco independiente. El SO puede asignar a páginas de diversos procesos el **mismo conjunto de marcos**, para aumentar la capacidad percibida de memoria.
- **Compartir segmentos de texto**, o mejor aún, **bibliotecas de sistema**.

Para ofrecer este modelo, el sistema operativo debe garantizar que las páginas correspondientes a las secciones de texto (código de programa) sean de sólo lectura.

> Un programa que está compilado de forma que permita que todo su código sea de sólo lectura posibilita que diversos procesos entren a su espacio en memoria sin tener que sincronizarse con otros procesos que lo estén empleando.

!

## CoW (copy on write)

El mecanismo más frecuentemente utilizado para crear un nuevo proceso es el empleo de fork(). Este método es incluso utilizado normalmente para crear nuevos procesos, transifiriendo el ambiente (variables, por ejemplo, que incluyen cuál es la entrada y salida estándar). Gracias a la memoria compartida el costo de fork() en un sistema Unix es muy bajo, se limita a crear las estructuras necesarias en la memoria del núcleo. Tanto **el proceso padre como el proceso hijo comparten todas sus páginas de memoria**, sin embargo, siendo dos procesos independientes, **no deben poder modificarse más que por los canales explícitos de comunicación entre procesos (IPC)**. Esto ocurre así gracias al mecanismo **CoW**. Las páginas de memoria de ambos procesos **son las mismas mientras sean sólo leídas**. Sin embargo, si uno de los procesos modifica cualquier dato en una de estas páginas, esta se copia a un nuevo marco, y deja de ser una página compartida. El resto de las páginas seguirá siendo compartida.
Esto se puede lograr marcando todas las páginas compartidas como _sólo lectura_, con lo cual cuando uno de los dos procesos intente modificar la información de alguna página se generará un fallo. El sistema operativo, al notar que esto ocurre sobre un espacio CoW, en vez de responder al fallo terminando al proceso, copiará sólo la página en la cual se encuentra la dirección de memoria que causó el fallo, y esta vez marcará la página como _lectura y escritura_.

!

## Demand Loading

La memoria virtual entra en juego desde la carga misma del proceso. Se debe considerar que hay una gran cantidad de _código durmiente_: aquel que sólo se emplea eventualmente, en situaciones particulares. Si bien a una computadora le sería imposible ejecutar código que no esté cargado en memoria, éste sí puede comenzar a ejecutarse sin estar completamente en memoria: **basta con haber cargado la página donde están las instrucciones que permiten continuar con su ejecución actual**.
La **paginación sobre demanda** significa que, al comenzar a ejecutar, el SO carga solamente la **porción necesaria** para comenzar la ejecución (posiblemente una o ninguna página), y que a lo largo de la ejecución, el paginador _es flojo_.
Estructura empleada por la MMU para implementar un paginador flojo será similar a buffer de traducción adelantada: la _tabla de páginas_ incluirá un _bit de validez_, indicando para cada página del proceso si está presente o no en memoria. Si el proceso intenta emplear una página que esté marcada como no válida, esto causa un fallo de página, que lleva a que el sistema operativo lo suspenda y traiga a memoria la página solicitada para luego continuar con su ejecución:

- Verifica en el PCB si esta solicitud corresponde a una página que ya ha sido asignada a este proceso.
- En caso de que la referencia sea inválida, se termina el proceso.
- Procede a traer la página del disco a la memoria. El primer paso es buscar un marco disponible. (por ej, por medio de una tabla de asig de marcos)
- Solicita al disco la lectura de la página en cuestión hacia el marco especificado.
- Una vez que finaliza la lectura de disco, modifica tanto al PCB como a la TLB para indicar que la página está en memoria.
- Termina la suspensión del proceso, continuando con la instrucción que desencadenó al fallo. El proceso puede continuar sin notar que la página hacía sido intercambiada.

Llevando esto al extremo, se puede pensar en un sistema **puramente sobre demanda**. Ninguna página llegará al espacio de un proceso si no es mediante un fallo de página.
La paginación sobre demanda puede impactar fuertemente al rendimiento de un proceso (dado el acceso al disco). Leer desde la página 278 para más información.

# Memoria virtual

## _OPT_

El enunciado será elegir somo página vćtima a aquella página que no vaya a ser utilizada por un tiempo máximo (o nunca más).

Características:

- Ofrece una cota mínima.
- Algoritmo meramente de interes teórico.
- Es impracticable.

## _LRU_

Busca acercarse a $OPT$ prediciendo cuándo será la próxima vez en que se emplee cada una de las páginas que tiene en memoria basado en la historia reciente de su ejecución. Elige la página que no ha sido empleada hace más tiempo. Se puede implementar con:

- un contador para cada uno de los marcos y aumentarlo siempre que haga una referencia a esa pagina:
  - no eficiente, tengo que recorrer todas las paginas para encontrar el menor
- lista doblemente enlazada:
  - la actualización requiere más operaciones
  - encuentra a la víctima en tiempo constante

Características:

- Es punto medio entre $OPT$ y $FIFO$.
- Requiere apoyo de hardware más complejo que para $FIFO$.
- $LRU$ y $OPT$ están libres de la anomalía de Belady

## _MFU/LFU_

Se basan en mantener un contador, tal como lo hace $LRU$, pero en vez de medir tiempo, miden la cantidad de referencias que se han hecho a cada página.

- $MFU$: si una página fue empleada muchas veces, probablemente vuelva a ser empleada muchas veces más
- $LFU$: si una página fue empleada pocas veces, es probablemente una página recién cargada, y va a ser empleada en el futuro cercano.
  Características:
- Son caros de implementar como $LRU$
- No tienen un rendimiento tan cercano a $OPT$
- No son utilizados

## Aproximaciones a _LRU_

Por la complejidad que existe para el hardware al implementar $LRU$, existen esquemas que tratan de aproximarse:

### Bit de referencia

Consiste en que todas las entradas de la tabla de páginas tengan un bit adicional, al que se le llama bit de referencia. Al iniciar la ejecución, todos los bits de referencia están apagados (0). Cada vez que se referencia a un marco, su bit de referencia se enciende. **(Esto, en gral, lo realiza el hardware)**. El sistema operativo invoca periódicamente a que se apaguen nuevamente todos los bits de referencia. Si se presenta un fallo, se elige por $FIFO$ sobre el subconjunto de marcos que no hayan sido referenciados en el periodo actual (todos los que esten en 0).

### Columna de referencia

Una mejora delt bit de referencia, es agregar varios bits de referencia, conformándose como una columna: en vez de descartar su valor cada vez que transurre el periodo determinado, el valor de la columna de referencia es desplazado a la derecha, descartando el bit más bajo (una actualización sólo modifica el bit más significativo). Cuando el sistema tenga que elegir una nueva página víctima, lo hará de entre el conjunto que tenga un número más bajo.

> Tiene un simple mantenimiento: recorrer una series de bits es una operación muy sencilla. Seleccionar el numero más bajo requiere una pequeña búsqueda, pero es mucho más sencillo que $LRU$.

### Segunda oportunidad (o reloj)

Está basado en un bit de referencia y un recorrido tipo $FIFO$. La diferencia es que además de que hay eventos que encienden a este biti (efectuar una referencia al marco), hay otros que lo apagan:
se mantiene un puntero a la próxima victica y cuando el sistema requiera efectuar un reemplazo, éste verificará si el marco al que apunta tiene el bit de referencia encendido o apagado. En caso de estar apagado, el marco es seleccionado como víctima, pero en caso de estar encendido (indicando que utilizado recientemene), se le da una segunda oportunidad: el bit de referencia se apaga, el apuntador de víctima potencial avanza una posición, y vuelv a intentarlo.

- Se puede implementar con una lista doblemente enlazada donde se avanza sobre la lista de marcos buscando uno con el bit de referencia apagado, y apagando a todos a su paso. (Como una aguja de **reloj**)
- En el peor de los casos se degenera en $FIFO$.

### Segunda oportunidad mejorada

Además del bit de referencia existe un **bit de modificación**, por lo tanto tenemos:

- $(0,0)$ No ha sido utilizado ni modificado recientemente. **Ideal para reemplazo**
- $(0,1)$ No ha sido utilizada recientemente, pero está modificada. No es tan buena opción, porque es necesario escribir la página a disco antes de reemplazarla, pero **puede ser elegida**
- $(1,0)$ El marco está limpio, pero fue empleado recientemente, por lo que probablemente se vuelva a requerir pronto.
- $(1,1)$ Empleada recientemente y sucia (sería necesario escribit la página a disco antes de reemplaza, y probablemente vuelva a aser requerida pronto). **Hay que evitar reemplazarla**

La lógica para encontrar una página víctima es **similar a segunda oportunidad**, pero busca reducir el costo de E/S. Esto puede requerir, sin embargo, dar hasta **cuatro vueltas** (por cada una de las listas) para elegir la página víctima.

## Asignación de marcos

Trabajamos con un ejemplo con un sistema que tiene 1024kb de memoria, 256 páginas de 4096 bytes cada una.

#### Puramente sobre demanda

Si el SO ocupa 248kb el primer paso será reservar las 62 páginas que éste requiere\
($techo(248000b/4096b) + 1$), y destinar 194 páginas restantes para los procesos a ejecutar.
Conforme se van lanzando y comienzan a ejecutar los procesos, cada vez que uno de ellos genere un fallo de página, se le irá asignando uno de loas marcos disponibles hasta causar que la memoria entera esté ocupada. Cuando un proceso termina, todos los marcos que tenía asignado volverán a la lista de marcos libres.
Una vez que la memoria esté completamente ocupada, el siguiente fallo de página invocará a un algoritmo de reemplazo de página, que decidirá de las 194.
Este esquema si bien es simple, al requerir una gran cantidad de fallos de página explícitos puede penalizar el rendimiento del sistema (es **demasiado flojo**).

> Dentro de la memoria del sistema operativo, al igual que la de cualquier
> otro proceso, hay regiones que deben mantenerse residentes y otras que pueden paginarse.

#### ¿Cómo mejoramos esto?

#### Mínimo de marcos

Si un proceso tiene asignados muy pocos marcos, su rendimiento indudablemente se verá afectado. Cada instrucción del procesador puede, dependiendo de la arquitectura, desencadenar varias solicitudes y potencialmente varios fallos de página.
Todas las arquitecturas proporcionan **instrucciones de referencia directa a memoria (instrucciones que permiten especificar una dirección de memoria para leer o escribir)** esto significa que todas requerirán que, para que un proceso funcione adecuadamente, tenga por lo menos dos marcos asignados.

> Ejemplo: si tuviese **solo un marco** la instrucción ubicada en _0x00A2C8_ solicita la carga de _0x043F00_, ésta causaría dos fallos: el primero, cargar al marco la página _0x043_, y el segundo, cargar nuevamente la página _0x00A_ para leer la siguiente instrucción a ejecutar del programa.

Otras arquitecturas, además, permiten _referencias indirectas a memoria_, esto es, la dirección de carga puede solicitar la dirección que está referenciada en un página.
Cada nivel de indirección que se permite aumenta en uno el número de páginas que se deben reservar como mínimo por proceso.

#### Esquema de asignación de marcos

##### Todos los marcos que solicita un proceso

El rendimiento de un proceso será mejor entre menos fallos de paginación cause, por lo tanto se puede pensar en otorgar a cada proceso el total de marcos que solicita.

- Disminuye el grado de multiprogramación.
- Reduce el uso efectivo total del procesador.

#### Asignación igualitaria

Se divide el total de espacio en memoria física entre todos los procesos en ejecución, en partes iguales.

- Es deficiente para casi todas las distribuciones de procesos.

> Ejemplo: $P_1$ es Firefox y podría estar empleando 2048kb (512 páginas) de memoria virtual (a pesar de que el sistema tiene sólo 1 mb de memoria física), no lo hace porque está $P_2$ que es Vim y requiere solo 112kb (28 páginas).

#### Asignación proporcional

Dar a cada procesouna porción del espacio de memoria física proporcional a su uso de memoria virtual. Cada proceso recibirá:
$$F_p = V_p/V_t * m$$
Donde $F_p$ indica el espacio de memoria física que el proceso recibirá, $V_p$ la catidad de memoria virtual que está empleando y $m$ la cantidad total de marcos de memoria disponibles. $V_t$ es el total de memoria virtual usada.

> Ejemplo: del ejemplo anterior agregamos $P_3$ = 560kb (140 pag), $P_4$ = 320kb (80 pag). Tenemos entonces que $V_t = 512 + 28 + 140 + 80 = 760$. Luego $P_1$ recibe 130 marcos, $P_2$ 7 , $P_3$ 35, $P_4$ 20.

Este esquema debe cuidar que:

- Ningún proceso debe tener asignado menos del mínimo de marcos definido.
- No sobre-asignar recursos a un proceso obeso.

Características:

- No tiene en cuenta las prioridades que hoy en día manejan todos los SO, se podría incluir como factor la prioridad, multiplicando junto con $V_p$.
- Sufre cuando cambia el nivel de multiprogramación, esto es, cuando se inicia un nuevo proceso o finaliza, deben **recalcularse** los espacios en memoria física asignados a cada uno de los procesos restantes. (Si finaliza el proceso el problema es menor)
- Tiende a desperdiciar recursos.

#### Ámbitos del algoritmo de reemplazo de páginas

Para atender los problemas, se puede discutir el ámbito en que operará el algoritmo de reemplazo de páginas cuando **se produce un fallo**.

- **Reemplazo local**: mantener tan estable como sea posible el cálculo hecho por el esquema de asignación empleado. Las únicas páginas que se considerarán para su intercambio serán aquellas pertenecientes **al mismo proceso** que causo el fallo. Un pro proceso tiene asignado su espacio de memoria física, y se mantendrá estable mientras el sistema operativo no tome alguna decisión por cambiarlo.
- **Reemplazo global**: los algoritmos de asgnación determinan el espacio asignado a los procesos al ser inicializados, e influyen a los algoritmos de reemplazo. Los algoritmos de reemplazo de páginas operan sobre el **espacio completo de memoria**, y la asignación física de cada proceso puede variar según el estado del sistema momento a momento.
- **Reemplazo global con prioridad**: es un esquema mixto, en el que un proceso puede sobrepasar su límite siempre que le robe espacio en memoria física exclisivamente a procesos de prioridad inferior a él. Esto es consistente con el comportamiento de los algoritmos planificadores.

> El reemplazo local es más rígido y no permite mejorar el rendimiento que tendría el sistema si aprovechara los periodos de inactividad de algunos de los procesos.

> Los esquemas basados en reemplazo global pueden llevar a rendimiento inconsistente: dado que la asignación de memoria física sale del control de cada proceso puede que la misma sección de código presente tiempos de ejecución muy distintos si porciones importantes de su memoria fueron paginadas a disco.

# Hiperpaginación

Es un fenómeno que puede presentarse por varias razones:

- Bajo un esquema de reemplazo local: cuando un proceso tiene asignadas pocas páginas para llevar a cabo su trabajo, y genera fallos de página con tal frecuencia que le imposibilita realizar trabajo real.
- Bajo un esquema de reemplazo global: cuando hay demasiados procesos en ejecución en el sistema y los constantes fallos y reemplazos hacen imposible a todos los procesos involucrados avanzar.

Una solución sería reducir el nivel de multiprogramación. Podría seleccionarse el proceso con menor prioridad, el que esté causando más cantidad de fallos, o al que esté ocupando más memoria.

# Virtual memory in Linux

## Zonas de memoria

El sistema operativo debe decidir qué porción de la memoria física asigna a memoria interna del núcleo (en donde habrá buffers, datos y el código mismo del núcleo) y qué porción será asignada dinámicamente (memoria dinámica del **sistema**) para procesos y cachés. Además hay porciones de memoria **reservadas** por el hardware o para uso específico del hardware y que el núcleo **no** puede utilizar libremente (dispositivos mapeados en memoria, vectores de interrupciones, etc), la configuración exacta depende de la arquitectura del hardware, en los x86 GNU/Linux se utiliza la siguiente disposición:

!

- Reservado para el hardware. (Configuración de hardware detectada durante el POST (Power On Self Test))
- Disponible para memoria dinámica.
- Reservado para el hardware (dispositivos mapeados a memoria y rutinas de bios).
- Núcleo
- Disponible para memoria dinámica

Se decide cargar el núcleo después de la memoria reservada para el hardware para poder cargarlo en un espacio de memoria contiguo.

## Optimizaciones y características

- **memoria compartida entre procesos (e hilos)**: una página que está en memoria puede estar siendo referenciada desde una, dos o más tablas de paginación. El sistema permite que un marco de página sea utilizado por varios procesos.
- **Copy On Write** para evitar duplicar todas las páginas de un proceso en fork().
- **demand loading**: las páginas se van leyendo o creando a partir de la información del programa binario a medida que es necesario.
- **memory mapped files**: un proceso puede solicitar que una porción de su memoria virtual se refiera a un archivo. Así, escribir/leer en un archivo consiste en escribir/leer directamente en una dirección de memoria. Para liberar esa página no es conveniente escribirla en swap, sino que conviene escribirla directamente en el espacio reservado para el archivo.
- **readahead**: cuando se lee un bloque es muy alta la probabilidad de que sea necesario leer en poco tiempo más el bloque siguiente. Por esto se utilizan cachés de disco que permiten leer secuencialmente varios bloques contiguos cuando en principio sólo se necesita el primero.
- **NUMA (Not Uniform Memory Access)**: se utiliza típicamente en equipos multiprocesadores, en donde determinadas porciones de memoria (nodos) están asociadas a un procesador brindando una velocidad de acceso mayor a ese procesador (con respecto al resto de la memoria dle cluster o del equipo). Cuando se utiliza NUMA la memoria es paricionada en nodos y a su vez cada nodo puede subdividirse en zonas.
- **reverse mapping**: además de las tablas de paginación de cada proceso, para el funcionamiento del algoritmo de reemplazo de páginas se debe almacenar cierta información sobre cada marco "candidato", por ej: si la página está bloqueada en memoria, qué entradas en tablas de traducciones están apuntando a esta página, si fue utilizada hace poco, etc. Los punteros a las entras en las tablas de traducciones son necesarios para poder actualizar las tablas correspondientes cuando se elige la página como víctima. El proceso de obtener las entradas que apuntan a determinado marco se llama _reverse mapping_. Se utilizan punteros a regiones de memoria para obtener la información.
- **atomic allocation request**: si se necesita un nuevo marco de memoria como parte del procesamiento de una interrupción no se puede esperar a que el gestor de memoria envíe una página al disco o actualice muchas estructuras de datos. Otro caso similar es durante el procesamiento de código en una sección crítica del núcleo. Para estos casos, cuando se requiere memoria, **el núcleo no hace un pedido normal de memoria**, sino que existe un mecanismo llamado **atomic allocation request**. Oara esto se necesita una reserva (pool) de páginas destinadas sólo a esos casos.

## Gestión de memoria libre

GNU/Linux utiliza paginación en los espacios de direcciones de los procesos, hacerlo también para la memoria gestionada por el núcleo y para rastrear la memoria libre/usada resulta casi imposible:

- Los controladores de DMA requieren de memoria (física) contigua para poder leer/escribir masivamente datos desde/hacia los dispositivos de almacenamiento. Si se utilizara paginación, tal vez se necesite desfragmentar la memoria para construir huecos lo suficientemente grandes (la gestión se complica).
- Cada vez que se hace una modificación en la tabla de paginación activa, la CPU vacía automáticamente la TLB. Hacer eso con la memoria del sistema o del núcleo penalizaría mucho el rendimiento.
- Utilizar un tamaño de página más grande (4mb) para el núcleo y áreas reservadas aumenta mucho la eficiendia de la TLB, pero si se usa paginación se deberían utilizar páginas de 4kb.

Por estas razones, se emplea un método muy conocido para hacer el seguimiento de la memoria libre: el **buddy system**. La información sobre los bloques de memoria libre se guarda en una estructura de datos que puede verse como un arreglo de listas. Los bloques de memoria libre se agrupan en potencias de dos, al elemento 0 del arreglo le corresponde la información sobre huecos de tamaó de una página, la lista en el elemento 1 tiene información de huecos de 2 páginas, etc. GNU/Linux utiliza 11 potencias de dos, así los huecos más grandes tienen $2^{11}$ páginas.

!

Cuando se necesita asignar un bloque contifuo de memoria se busca el primer hueco lo suficientemente grande como para satisfacer el pedido. Si se necesita partir un hueco grande, se asigna lo necesario y el espacio restante se añade a las listas correspondientes.
Los opuesto ocurre cuando se libera una porción de memoria: en este caso se añaden los huecos a las listas correspondientes. Si en una lista quedan dos bloques "colegas" (vecinos en memoria y alineados al siguiente tamaño más grande), esos dos bloques pueden fundirse para formar un nuevo bloque más grande.
**De esta manera se soluciona el problema de la fragmentación externa**

> El buddy system no puede utilizarse para reservar memoria en porciones más chicas. Sin embargo, esto es una tarea también bastante habitual. Por esto existe otra porción del manejo de memoria que se encarga de gestionar pedidos más chicos de memoria: el **slab allocator**. Esta gestión permite reducir la fragmentación interna.

#### Asignación de memoria

La memoria RAM se asigna indistintamente a procesos y a caché. Todos pueden crecer indiscriminadamente (si hay pocos procesos posiblemente hay a mucha memoria utilizada para caché y viceversa).

## Reclamo de páginas

¿Qué ocurre cuando la memoria se llena?
Antes de que se llene, el _algoritmo de reclamo de marcos del núcleo (page frame reclaiming algorithm - PFRA -)_ se encarga de rellenar la lista de bloques libre "robando" marcos de procesos (en modo usuario) y de los cachés del núcleo. Esto se debe hacer antes de que la memoria se agote completamente pues para escribir los datos en disco (si hace falta) se necesitan también algunas páginas de memoria. Esto es: **el algoritmo de reclamo de marcos conserva un pool de marcos libres mínimo**.
El algoritmo manea los marcos de diferente manera según su contenido:

!

- Hay páginas que pueden estar _bloqueadas en memoria_. este bloqueo puede ser temporal (ej. entrada/salida o sección critica del núcleo) o permanente (ej. pedido explícito del proceso).
- Las páginas _anónimas_ son aquellas que forman parte del espacio de memoria virtual de un proceso (segmento de código, datos, etc) y no contienen datos provenientes de archivos (librerías, archivos map en memoria, etc).
- Algunas páginas pueden contener archivos mapeados en memoria: estas páginas aparecen dentro del espacio de **memoria virtual** de un proceso pero sus datos provienen de un archivo.
- El sistema tiene cachés para distintos tipos de datos: direntries, inodos, datos de archivos, etc. Algunos tipos de dato se usan más frecuentemente que otros. Los datos que están en caché podrían estar modificados en memoria y en ese caso, para liberar la memoria ocupada se deben escribir los datos en el lugar correspondiente en el disco (y puede involucrar actualizar otros datos).

## Principio del PFRA

El algoritmo de reemplazo de marcos es una pieza de software compleja y no responde (al menos directamente) a ningún marco teórico: es más bien **una series de criterios que se han ido afinando en el tiempo, según parámetros y algoritmos más específicos para casos particulares**. Aunque hay algunas reglas generales:

- Liberar primero las páginas que provoquen menos daó (páginas de cachés).
- Todas las páginas de un proceso (salvo las bloqueadas en memoria) son reclamables.
- Antes de liberar un página compartida, se deben ajustar las entradas en las tablas de paginación de los procesos involucrados (**esto se hace con reverse mapping**).
- Reclamar sólo páginas no utilizadas recientemente (versión simplificada de $LRU$), utilizando el bit Accessed.
- En lo posible elegir las páginas limpias (no-dirty). Esto ahorra la escritura en el disco.

El reclamo de páginas se hace en forma periódica a través de un proceso llamado $kswapd$. También hay un mecanismo similar para recuperar memoria de los buffers utilizados por el **slab allocator**.
Si falla algún pedido de memoria (**low on memory**) se disparan mecanismos más agresivos para recuperar la memoria que **consisten principalmente en achicar el tamaño de los cachés**.
Incluso, si la situción se torna muy crítica, el núcleo puede decidir eliminar un proceso (sin siquiera enviarlo a swap). De tomar esta decisión se encarga el **Out of Memory (OOM) Killer**. Esta decisión no es sencilla: se intenta elegir un proceso bastante grande, que no haya hecho demasiado progreso y que no esté involucrado en secciones críticas, I/O o tareas del núcleo que puedan llegar a dejar el sistema inconsistente.

## swap

Para reaalizar el intercambio de página de swap con el disco se utiliza un caché de swap: de esta forma, si se necesita una página que fue escrita en disco pero que todavía está en el caché no es necesario traerla nuevamente del disco. Hay que tener en cuenta problemas de concurrencia:

- _Multiple swap-in_: el núcleo debe tomar las medidas para que una página compartida no sea cargada dos veces en memoria (**convirtiendose en una página no compartida!**).

> El proceso A intenta acceder a una página compartida con el proceso B y que está en swap. Lanzará el pedido para obtener tal página. Mientras se efectúa la lectura, puede ocurrir que el proceso B también intente acceder a esa página y el sistema operativo al notar que no está en memoria lance un nuevo pedido. Así, cuando el disco termine las dos lecturas cada proceso tendrá una copia distinta de la misma página que por lo tanto ya no estará compartida.

- _swap-in y swap-out concurrentes_: otra situación nefasta puede darse cuando el sistema decide enviar una página al swap. Si antes de que se efectivice la escritura el proceso intenta utilizar esa página y detecta que no está en memoria podría traer del disco una versión anterior de la página.
