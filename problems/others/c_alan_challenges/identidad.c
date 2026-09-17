#include <stdio.h>
#include <stdlib.h>

int main() {
  int rows;
  printf("Insert rows quantity: ");
  scanf("%d", &rows);

  int columns;
  printf("Insert columns quantity: ");
  scanf("%d", &columns);

  if (columns != rows) {
    printf("It will be not be the identity matrix...\n");
    return 0;
  }


  int* matrix = calloc(columns * rows, sizeof(int));

  printf("%d, %d, %d, %d", rows, columns, sizeof(int), sizeof(matrix));

  printf("Insert and press enter for every index of each column.\n");
  for(int j = 0; j < columns; j++) {
    printf("Column %d:\n", j);
    for(int i = 0; i < rows; i++) {
      int index;
      scanf("%d", &index);
      matrix[(j * rows) + i] = index;
    }
  }

  for(int j = 0; j < columns; j++) {
    for(int i = 0; i < rows; i++) {
      int index = matrix[(j * rows) + i];
      if((i == j && index != 1) || (i != j && index)) {
        printf("The matrix is not the identity.");
        free(matrix);
        return 1;
      }
    }
  }

  free(matrix);

  printf("The matrix is the identity.");
  return 0;
}
