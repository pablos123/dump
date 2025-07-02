#ifndef GOLCOORDS
#define GOLCOORDS

#include <stdio.h>
#include <stdlib.h>

/******************************************************************************/
/*
 * Estructura de coordenadas con tres elementos.
 * Un entero no negativo que representa el número de fila de una matriz.
 * Un entero no negativo que representa el número de columna de una matriz.
 * Un character representando True ó False.
 * */
typedef struct{
  size_t i;
  size_t j;
  char isChecked;
}Coord;
	
typedef Coord* CoordP;

/*************************************************************************/

/*
 * Toma un numero entero y un entero no negativo representado un máximo 
 * y devuelve un numero entero no negativo al cual llamamos normalizado.
 * */
size_t normalize(int a, size_t max);

/*
 * Crea un array de coordenadas antes mencionadas, será de tamaño rowCount * columnCount
 * */
CoordP* coordArray(size_t rowCount, size_t columnCount);

/*
 * Limpia el caracter representando True ó False de cada elemento de un array de coordenas.
 * */
CoordP* cleanCoordArray(size_t rowCount, size_t columnCount, CoordP* coordArray);

/*
 * Destroys coords
 * */
void destroy_coords(CoordP*, size_t rowCount, size_t columnCount);

#endif
