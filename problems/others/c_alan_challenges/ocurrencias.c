#include <stdio.h>

size_t length(char* str) {
  size_t c = 0;
  while (str[c++] != '\0');
  return c - 1;
}

int main() {
  char input[20];
  printf("Insert a word to count the repetead characters: ");
  fgets(input, 20, stdin);

  int counter[60];
  for(size_t i = 0; i < 60; i++) {
    counter[i] = 0;
  }

  size_t l = length(input) - 1;

  for(size_t i = 0; i < l; i++) {
    char c = input[i];
    printf("%d ", c);
    if ((c > 'A' && c < 'Z') || (c > 'a' && c < 'z')) {
      c -= 65;
      counter[c]++;
    } else {
      printf("Bad input characters.");
      return 1;
    }
  }

  printf("Caracteres repetidos:\n");
  for(size_t i = 0; i < 60; i++) {
    if(counter[i] > 1) {
      printf("%c: %d", i, counter[i]);
    }
  }

  return 0;
}
