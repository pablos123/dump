# Sistemas de archivos

Un sistema de archivos sirve para gestionar información persistente. Debe permitir:

- Guardar información
- Consultarla
- Actualizarla
- Eliminarla

## TAR (UNIX)

Ventajas:
- Simple

Desventajas:

- Acceso secuencial
- Actualización compleja
- Los archivos están en un sub bloque

## Commodore-64

Trató de concentrar la metadata.

Ventajas:

- Simple
- Es más rápido saber si un archivo está o no

Desventajas:

- Actualización compleja
- Tamaño fijo del sector de cabeceras
- Los archivos están en un sub bloque

## Questar/MFS

Trató de permitir la fragmentación de archivos.

Problema: fragmentación acotada.
En este esquema un subdirectorio es simplemente un archivo solo que sus fragmentos son dir entries.

## MSDOS (FAT)

Se basa en unificar dos aspectos:

- Gestión del espacio libre
- Permitir gestionar la fragmentación arbitraria

Ventajas:

- easy to grow file
- no external fragmentation
- no artificial limit to # of files

Desventajas:

- not robust if disk is flaky (i.e. if the directory messes up, we are toast)
- sequential reads can require lots of seeking (but the defragmenter can fix this)
- lseek requires O(N) of time

## UNIX

El sector lógico de un i-node (information node) es de 512 bytes (coincide con el sector físico) y tiene:

## Berkeley Software Distribution (BSD)

The Berkeley file system is extremely similar to the UNIX file system, but it also adds a block bit map. This allows the file system to know whether a data block is free.

BSD still succumbs to external (similar to FAT) and internal fragmentation.

## Cómo mejoró BSD el sistema de archivos? Y otras mejoras

### Haciendo crecer el sector lógico

BSD planteó un sector lógico distinto del físico. El sector lógico de BSD era de 4096 en lugar de 512 bytes. Se leían 4096 (8 sectores) porque aunque los programas leían de a 512 bytes, el sistema operativo pedía de a 8 de estos sectores. Entonces cuando el program pedía los póximos 512 bytes. el sistema operativo ya los tenía en cache.

### Mejorando los movimientos del disco

Teniendo en cuenta que un disco tiene dos tipos de moviemientos:
- Rotación de platos (angular)
- Cabezal (radial)

**Mejorando el rendimiento angular**

Puedo optimizarlos. Se puede acelerar el acceso a un disco no poninendo dos sectores seguidos.
Si quiero leer 1 y 2 y están pegados quizás termino de leer 1 y quiero leer 2 pero me pase entonces tengo que esperar que el disco de toda la vuelta. En cambio si 2 no está pegado a 1 no tengo que esperar eso. Esto minimiza la cantidad de revoluciones para leer.

**Mejorando el rendimiento radial**

Para mejorar el rendimiento del moviemiento radial se usa el **algoritmo del ascensor**: recolectar pedidos de lectura/escritura y reodenarlos de modo de no har más de una o dos pasadas. Es óptimo excepto que requiere que los pedidos de lectura/escritura sean independientes.
Es decir, al inicio el cabezal está detenido. Al llegar la primer petición va una dirección. Cada pedido que lega se va cumpliendo en el orden en que aparecen en el recorrido del cabezal hasta el final del recorrido, luego se empieza el recorrido inverso y se responden los de esa dirección y así sucesivamente.

### Distribución del superblock

Si el sistema se cae en el medio de la creación de un directorio queda un FS inconsistente que hay que devolver a un estado consistente.
Esto lo hace el fsck (File System Checker). Para esto es que las operaciones de creación deben ordenarse. Lo siguiente a mejorar consiste en distribuir el superblock. En vez de tenerlo al principio del disco lo distribuyo en partes en el disco.
Entonces una operación en vez de tener que ir al superblock al principio del disco solo tiene que ir al más cercano.
Es además más seguro porque si falla la creación en el file system que tiene todo el superblock en el principio se corrompe todo el disco.
En el file system que tiene superblocks distribuidos solo se corrompe una parte del disco .

## Más mejoras

Como ejemplo tomemos la apertura de un archivo, el núcleo debe:

- buscar en el directorio correspondiente (un directorio es un arreglo de dir entries O(n))
- sacar su i-nodo de información
- chequear los accesos
- construir el descriptor en el System Segment

**Podemos acelerar esto cambiando el arreglo por otra estructura. (Por ejemplo un árbol!).**

### Journaling

El journaling son acciones que se toman para, frente a un cambio de metadata permitir volver atrás cambios parciales y alcanzar un estado consistente. Es muy usado, por ejemplo, en bases de datos. En esencia se guardan los valores intermedios de la metadata con un timestamp.
Journaling baja la performance pero aumenta la seguridad.

#### Otras

- Para buscar un ejecutable tener una base de datos con las ubicaciones de los ejecutables y traerlos con una busqueda con hash.

# Bibliography

[UCLA CS111 – File Systems](https://web.cs.ucla.edu/classes/spring12/cs111/scribe/12a/)
