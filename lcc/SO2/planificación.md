# Planificacion conceptos básicos

La planificación de procesos se refiere a cómo determina el sistema operativo el orden en que irá cediendo el uso del procesador a los procesos que lo vayan solicitando, y a las polícicas que empleará para que el uso que den a dicho tiempo no sea excesivo respecto al uso esperado del sistema.

## Tipos de planificación

#### **A largo plazo**:

Las decisiones eran tomadas considerando los requiitos pre-declarados de los procesos y los que el sistema tenía libres al termina algún otro proceso.
Muy frecuente en los sistemas multiprogramados en lotes.
En los sistemas de uso interactivo, casi la totalidad de los que se usan hoy en día, este tipo de planificación no se efectúa, dado que es típicamente el usuario quien indica expresamente qué procesos iniciar.

#### **A mediano plazo** (Scheduler):

Decide qué procesos es conveniente bloquear en terminado momento, sea por escasez/saturación de algún recurso (como la memoria primaria) o porque están realizando alguna solicitud que no puede satisfacerse.
Se encarga de tomar decisiones respecto a los procesos conforme entran y salen del estado de **bloqueado**. Típicamente, están a la espera de algún evento externo o de la finalización de transferencia de datos con algún dispositivo.

#### **A corto plazo** (Dispatcher):

Decide cómo compartir momento a momento el equipo entre todos los procesos que requieren de sus recursos, especialmente el procesador.
La planificación a corto plazo se lleva a cabo decenas de veces por segundo.
Tiene que ser código muy simple eficiente y rápido.
Es el encargado de planificar los **procesos que está listos para la ejecución**.

### Ubicación de planificadores

1. El planificador a largo plazo se encarga de admitir un nuevo proceso: la transición **de nuevo a listo**.
1. El planificador a mediano plazo maneja la activación y bloqueo de un proceso relacionado con eventos, esto es, la transiciones entre **en ejecución y bloqueado** y entre **bloqueado y listo**.
1. El planificador a corto plazo decide entre los procesos que están listos para ejecutarse y determina a cuál de ellos **activar**, detiene a aquellos que exceden sy tiempo de procesador. Transición entre **listo y en ejecución**.

## Tipos de proceso

Los procesos alternan entre ráfagas (**bursts**) en donde realizan principalmente cómputo interno (están limitador por CPU y CPU-bound) y otras operaciones en donde la atención está puesta en transmitir los datos desde o hacia dispositivos externos (están limitados por entrada-salida, I/O bound).
**Un proceso se suspende para realizar entrada-salida deja de estar listo y pasa a estar bloqueado**.

#### Procesos largos

Aquellos que por mucho tiempo (la definición de mucho tiempo depende de las políticas generales del sistema) han estado en **listos o ejecución**, esto es, procesos que estén en una larga ráfaga limitada por CPU.

#### Procesos cortos

Los que, ya sea que en este momento estén en una ráfaga limitada por entrada-salida y requieren atención meramente ocasional del procesador, o tienden a estar bloqueados esperando a eventos.

> Por lo general se busca dar un tratamiento preferente a los procesos cortos, en particular a los interectivos.

## Tiempo de uso

> Si a todas las operaciones sigue una demora de un segundo, el usuario sentirá menos falta de control si en promedio tardan medio segundo, pero ocasionalmente hay picos de cinco.

Unidades:

- **Tick**:
  Una fracción de tiempo durante la cual se puede realizar trabajo útil, esto es, usar el CPU sin interrupción (ignorando las interrupciones causadas por los dispositivos de entrada y salida y otras señales que llegan al CPU). El tiempo correspondiente a un tick está determinado por una señal (interrupción) periódica emitica por el temporizador (timer). La frecuencia con que ocurre esta señal se establece al inicio del sistema.
- **Quantum**:
  El tiempo mínimo que se permitirá a un proceso el uso del procesador.

### Tipos de tiempo

- **Tiempo núcleo o kernel**: tiempo que pasa el sistema en espacio de núcleo, incluyendo entre otras funciones (atención a interrupciones, el servicio a llamadas al sistema, diversas tareas administrativas) el empleado en **decidir e implementar la política de planificación** y los cambios de contexto. Este tiempo no se contabiliza cuando se calcula el tiempo del CPU utilizado por un proceso.

- **Tiempo de sistema**: tiempo que pasa un proceso en espacio núcleo atendiendo el pedido de un proceso (syscall). Se incluye dentro del tiempo de uso del CPU de un proceso y suele discriminarse del tiempo de usuario.

- **Tiempo de usuario**: tiempo que pasa un proceso en modo usuario, es decir, ejecutando las instrucciones que forman parte explícita y directamente del programa.

- **Tiempo de uso del procesador**: tiempo durante el cual el procesador ejecutó instrucciones por cuenta de un proceso (sean en modo usuario o en modo núcleo)

- **Tiempo desocupado (idle)**: tiempo en que la cola de procesos listo está vacía y no puede realizarse nungún trabajo.

# Algoritmos de planificación

El planificador a corto plazo puede ser invocado cuando un proceso se encuentra en algunas de las cuatro siguientes circunstancias:

1. Pasa de estar **ejecutando a en espera** (por ej. I/O, join, etc)
1. Pasa de estar **ejecutando a listo** (por ej. al ocurrir la interrupción del temporizador)
1. Pasa de estar **en espera a listo** (por ej. I/O)
1. Finaliza su ejecución y pasa de **ejecutando a terminado**.

En el primer y cuarto caso, el sistema operativo siempre tomará el control: en el primer caso, el proceso entrará en el dominio del planificador a mediano plazo, mientras que en el cuarto sadrá definitivamente de la lista de ejcución.

Un sistema que opera bajo multitarea apropiativa implementará también el segundo y tercer caso, mientras que uno que opera bajo multitarea cooperativa no necesariamente reconocerá dichos estados.

## Objetivos de la plaificación

- **Ser justo**: debe tratarse de igual manera a todos los procesos que compartan las mismas cracterísticas, y nunca postergar indefinidamente uno de ellos.

- **Maximizar el rendimiento**: dar servicio a la mayor parte de procesos por unidad de tiempo.

- **Ser predecible**: un mismo trabajo debe tomar aproximadamente la misma cantidad de tiempo en completarse independientemente de la carga del sistema.

- **Minimizar la sobrecarga**: el tiempo que el algoritmo pierda en burocracia debe mantenerse al mínimo, dado que éste es tiempo de procesamiento útil perdido.

- **Equilibrar el uso de recursos**: favorecer a los procesos que empleen recursos subutilizados, penalizar a los que peleen por un recurso sobreutilizado causando contención en el sistema.

- **Evitar la postergación indefinida**: aumentar la prioridad de los procesos más viejos para favorecer que alcancen a obtener algún recurso por el cual estén esperando.

- **Favorecer el uso esperado del sistema**: en un sistema con usuarios interactivos, maximizar la prioriidad de los procesos que sirvan a solicitudes iniciadas por éste (aún a cambio de penalizar a los procesos de sistema).

- **Dar preferencia a los procesos que podrían causar bloqueo**: si un proceso de baja prioridad está empleando un recurso del sistema por el cual más procesos están esperando, favorecer que éste termine de emplearlo más rápido.

- **Favorecer los procesos con un comportamiento deseable**: si un proceso causa muchas demoras (por ejemplo, atraviesa una ráfaga de I/O), se le puede penalizar porque degrada el rendimiento global del sistema.

- **Degradarse suavemente**: si bien el nivel ideal de utilización del procesador es al 100% es imposible mantenerse siempre a este nivel. Un algoritmo puede buscar responder con la menor penalización a los procesos preexistentes al momento de exceder este umbral.

## Pimero llegado, primero servido (FCFS)

Este es un **mecanismo cooperativo**, con la mínima lógica posible: cada proceso **se ejecuta en el order en que fue llegando, y hasta que suelta el control**.

## Ronda (Round Robin)

El esquema ronda **busca dar una relación de respuesta buena, tanto para procesos largos como para los cortos**.

**La principal diferencia entre la ronda y FCFS es que en este caso sí emplea multitarea apropiativa**: cada proceso que esté en la lista de procesos listos puede ejecutarse por un sólo quantum. Si un proceso no ha terimnado de ejecutar al final de sus quantum, será interrumpido y puesto al final de la lista de procesos listos, para que espere a su turno nuevamente. Los procesos que sean despertados por los planificadores a mediano o largo plazo se agregarán también al final de esta lista.

El procesador simulado sería cada vez más lento, dada la fuerte penalización que iría agregando la sobrecarga administrativa.

> Finkel se refiere a esto como el **principio de la histéresis: hay que resistirse al cambio**.

El algoritmo FCFS mantiene al mínimo posible la sobrecarga administrativa, y (aunque marginalmente) resulta en mejor rendimiento global.

Igualmente la ronda puede ser ajustada modificando la duración del tiempo de espera para hacer la interrupción, esto permite llegar a tiempos más cercanos a FCFS, ya que un round robin con un quatum muy grande es, en definitiva, FCFS.

## El proceso más corto a continuación (SPN, shortest process next)

Cuando no se tiene la posiblidad de implementar multitarea apropiativa, pero se requiere de un algoritmo más justo, contando con información por anticipado acerca del tiempo que requieren los procesos que forman la lista, puede elegirse el más corto de los presentes.
Ahora bien, es muy difícil contar con esta información antes de ejecutar el proceso. Es más frecuente buscar caracterizar las necesidades del proceso: ver si durante su historia de ejecución ha sido un proceso tendiente a manejar ráfagas limitadas por entrada-salida o limitadas por procesador y cuál es su tendencia actual.

### SPN apropiativo (PSPN, preemptive shortest process next)

A pesar de que intuitivamente daría una mayor ganancia combinar las estrategias de SPN con un esquema de multitarea apropiativa, el comportamiento obtenido es muy similar para la amplia mayoría de los procesos.
Lo bueno es que no penaliza tanto los procesos largos como uno esperaría y al despachar primero los procesos más cortos, mantiene la lista de procesos pendientes corta, lo que lleva naturalmente a menores índices de penalización.

## El más penalizado a continuación (HPRN, highest penalty ratio next)

En un sistema que no cuenta con multitarea apropiativa, las alternativas presentadas hasta ahora resultan invariablemente injustas: el uso de FCFS favorece los procesos largos, y el uso de SPN los cortos. Un intento de llegar a un algoritmo más balanceado es HPRN.

## Ronda egoísta (SRR, selfish round robin)

Este método busca favorecer los procesos que ya han pasado tiempo ejecutando que a los recién llegados. De hecho, los nuevos procesos no son programados directamente para su ejecución, sino que se les forma en la cola de procesos nuevos, y se avanza únicamente con la cola de procesos aceptados.

Para SRR se emplean los parámetros _a_ y _b_, ajustables según las necesidades del sistema. _a_ indica el ritmo según el cual se incrementará la prioridad de los procesos de la cola de procesos nuevos, y _b_ el ritmo del incremento de prioridad para los procesos aceptados. Cuando la prioridad de un proceso nuevo alcanza a la prioridad de un proceso aceptado, el nuevo se vuelve aceptado. Si la cola de procesos aceptados queda vacía, se acepta el proceso nuevo con mayor prioridad.

- Si b < a, la prioridad de un proceso entrante eventualmente alcanzará a la de los procesos aceptados y comenzará a ejecutarse. Mientras el control va alternando entre dos o más procesos, la prioridad de todos ellos será la misma (esto es, son despachados efectivamente por una simple ronda).
- Si b >= a, el proceso en ejecución terminará y otro será aceptado. En este caso, este esquema se convierte en FCFS.
- Si b = 0, los procesos recién llegados serán aceptados inmediatamente, con lo cual se convierte en una ronda.

## Retroalimentación multinivel (FB, multilevel feedback)

La ronda egoísta introduce el concepto de tener no una sino varias colas de procesos, que recibirán diferente tratamiento.
**Este mecanismo es muy poderoso y se emplea en prácticamente todos los planificadores en uso hoy en día**.

## Lotería

Bajo el esquema de la lotería, cada proceso tiene un número determinado de boletos y cada boleto le representa una oportunidad de jugar a la lotería. Cada vez que el planificador tiene que elegir el siguiente proceso a poner en ejecución, elige un número al azar y otorga el siguiente quantum al proceso que tenga el boleto ganador. El boleto ganador no es retirado, esto es, la probabilidad de que determinado proceso sea puesto en ejecución no varía entre invocaciones sucesivas del planificador.
Las prioridades pueden representarse en este esquema de forma muy sencilla: un proceso al que se le quiere dar mayor prioridad simplemente tendrá más boletos; si el proceso A tiene 20 boletos y el proceso B tiene 60, será tres veces más probable que el siguiente turn toque a B que a A.
**El esquema de planificación por lotería considera que los procesos puedan cooperar entre sí**.

# Conclusión

Podemos clasificar los algoritmos sobre dos discriminadores primarios:

- Si están pensados para emplearse en multitarea cooperativa o apropiativa.
- Si emplean información intrínseca a los procesos evaluados o no lo hacen, es es, si un proceso es tratado de distinta forma dependiendo de su historial de ejecución.
