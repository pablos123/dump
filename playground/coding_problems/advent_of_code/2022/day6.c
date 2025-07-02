#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MARKER_LENGTH 7


void main() {
    FILE* fh = fopen("./input.day6.orig", "r");
    if(fh == NULL) exit(1);

    char* fh_content = calloc(10000, 1);
    fgets(fh_content, 10000, fh);
    int str_len = strlen(fh_content);
    fclose(fh);

    if(str_len < MARKER_LENGTH) exit(1);

    clock_t t;
    t = clock();
    int i, j, k, q, b;
    for(i = 0; i < str_len - MARKER_LENGTH; ++i) {
        b = 1;
        for(j = i, q = 0; j < i + MARKER_LENGTH; ++j, ++q) {
            for(k = 1; k < MARKER_LENGTH - q; ++k) {
                if(fh_content[j] == fh_content[j + k]) {
                    b = 0;
                    break;
                }
            }
            if(!b) break;
        }
        if(b) break;
    }
    t = clock() - t;

    double time_taken = ((double)t)/CLOCKS_PER_SEC;
    printf("Result: %i\n", i + MARKER_LENGTH);
    printf("Time: %lf\n", time_taken);
}
