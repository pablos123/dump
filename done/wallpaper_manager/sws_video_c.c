#include <X11/X.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <assert.h>
#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// This program assumes 32-bit RGBA.

#define BYTES_PNG_CHECK 8

void is_png(FILE *file_handler) {
  void *buffer = malloc(BYTES_PNG_CHECK);
  assert(buffer);
  assert(fread(buffer, 1, BYTES_PNG_CHECK, file_handler) == BYTES_PNG_CHECK);
  assert(!png_sig_cmp(buffer, 0, BYTES_PNG_CHECK));
  free(buffer);
}

static unsigned char *read_png(FILE *file_handler, unsigned int height) {
  png_structp png =
      png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  assert(png);
  png_infop info = png_create_info_struct(png);
  assert(info);

  png_init_io(png, file_handler);
  png_set_sig_bytes(png, BYTES_PNG_CHECK);
  png_read_info(png, info);

  // Allocate memory for pixel data
  unsigned char *data = malloc(png_get_rowbytes(png, info) * height);
  png_bytep *rows = malloc(sizeof(png_bytep) * height);
  for (unsigned int y = 0; y < height; y++)
    rows[y] = data + y * png_get_rowbytes(png, info);

  png_read_image(png, rows);
  free(rows);
  png_destroy_read_struct(&png, &info, NULL);
  return data;
}

// Create a char* with all the pixel data of the image (RGBA).
char *create_xdata(unsigned char *data, unsigned int width,
                   unsigned int height) {

  char *xdata = (char *)malloc(width * height * 4); // Assume 32 bit
  for (unsigned int i = 0; i < width * height; ++i) {
    xdata[i * 4 + 0] = data[i * 4 + 2]; // Blue
    xdata[i * 4 + 1] = data[i * 4 + 1]; // Green
    xdata[i * 4 + 2] = data[i * 4 + 0]; // Red
    xdata[i * 4 + 3] = data[i * 4 + 3]; // Alpha
  }
  return xdata;
}

int main(int argc, char **argv) {
  assert(argc == 7);

  unsigned int width = atol(argv[2]);
  unsigned int height = atol(argv[3]);
  assert(width && height);

  unsigned int offset_x = atol(argv[4]);
  unsigned int offset_y = atol(argv[5]);

  int files_count = atol(argv[6]);
  assert(files_count);

  // Get display and default screen
  Display *display = XOpenDisplay(NULL);
  assert(display);
  int default_screen = XDefaultScreen(display);
  int default_depth = XDefaultDepth(display, default_screen);

  // Get root window
  Drawable root = (Drawable)XRootWindow(display, default_screen);

  Pixmap *pixmaps = malloc(sizeof(Pixmap) * files_count + 1);
  char *file_name = malloc(strlen(argv[1]) + 10);
  for (int i = 1; i <= files_count; ++i) {
    sprintf(file_name, "%s/%d.png", argv[1], i);

    // Open file
    FILE *file_handler = fopen(file_name, "rb");
    assert(file_handler);
    is_png(file_handler);

    // Read data, save the width and the height
    unsigned char *png_data = read_png(file_handler, height);
    assert(!fclose(file_handler));

    // Create xdata for XImage
    char *xdata = create_xdata(png_data, width, height);
    free(png_data);

    // Create XImage
    XImage *ximage =
        XCreateImage(display, DefaultVisual(display, default_screen),
                     default_depth, ZPixmap, 0, xdata, width, height, 32, 0);

    // Create the pixmap for the background
    Pixmap pixmap = XCreatePixmap(display, root, width, height, default_depth);

    GC gc = XCreateGC(display, pixmap, 0, NULL);
    XPutImage(display, pixmap, gc, ximage, 0, 0, offset_x, offset_y, width,
              height);

    // Cleanup
    XDestroyImage(ximage); // xdata free is here
    XFreeGC(display, gc);

    pixmaps[i - 1] = pixmap;
  }

  free(file_name);

  while (1) {
    for (int i = 0; i < files_count; ++i) {
      // Set the background
      XSetWindowBackgroundPixmap(display, root, pixmaps[i]);

      // Show changes
      XClearWindow(display, root);
      XFlush(display);

      usleep(10000);
    }
  }

  // Cleanup
  for (int i = 0; i < files_count; ++i)
    XFreePixmap(display, pixmaps[i]);
  free(pixmaps);
  XCloseDisplay(display);
  return 0;
}
