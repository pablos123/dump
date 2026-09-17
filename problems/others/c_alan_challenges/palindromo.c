#include <stdio.h>

// ingresar una string y decir si es palíndromo o no

size_t length(char* str) {
  size_t c = 0;
  while (str[c++] != '\0');
  return c - 1;
}

int main() {
  char input[20];
  fgets(input, 20, stdin);
  printf("Insert a word to know if it is a palindrome: ");

  size_t l = length(str) - 1;
  size_t len = l;

  for(size_t i = 0; i < len; i++) {
    char c = input[i];
    if (! (c > 'A' && c < 'Z') || (c > 'a' && c < 'z')) {
      printf("Bad input characters.");
      return 1;
    }
  }

  if (! l % 2) l = l / 2;
  else l = (l - 1) / 2;
  for (size_t i = 0; i < l; i++) {
    if (str[i] != str[len - i]) return 1;
    else continue;
  }

  if (! is_pal(input)) printf("The word '%s' is a palindrome.\n", input);
  else printf("The word '%s' is NOT a palindrome.\n", input);

  return 0;
}
