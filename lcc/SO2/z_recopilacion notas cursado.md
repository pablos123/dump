¿Qué relación tiene con virtualización la arquitectura MIPS?

¿Cómo se podría implementar BSD file system en Nachos?

**Multitarea cooperativa**:
El proceso decide cuando darle el control al sistema.
**Multitarea semi-cooperativa**:
Un proceso cuando hace una llamada a sistema el sistema toma el control y puede cambiar de tarea.
Problemas: un proceso sin llamada al sistema.

**Multitarea apropiativa (preentable)**:
Hay una interrupción hecha con una alarma las tareas están copletamente aisladas.

##### Diferencia entre programa y proceso

Programa: binario en el disco
Procesos: ejecuciones del programa.

##### Tipos de kernel

**Monolítico**: no hay diferenciación estricta en el sistema, todo corre con acceso a hardware. En gral no está estructurado.
**Microkernels**: limitan la func del kernel al mínimo: gestionar hardware y memoria virtual.

En general ahora mismo los kernels son híbridos.

##### Segunda oportunidad mejorada

En segunda oportunidad mejorada _NO_ tengo que escribir a disco si es un HIT.
Cuando hago un hit tengo que marcar ok el bit de lectura.
