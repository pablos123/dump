#include <X11/X.h>
#include <X11/Xlib.h>
#include <assert.h>
#include <cairo/cairo-xlib.h>
#include <cairo/cairo.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv) {
  assert(argc == 2);
  Display *dpy = XOpenDisplay(NULL);
  assert(dpy);

  int screen = XDefaultScreen(dpy);
  Window root_window = XRootWindow(dpy, screen);
  int w = XDisplayWidth(dpy, screen);
  int h = XDisplayHeight(dpy, screen);
  assert(w);
  assert(h);

  // Create a surface to draw
  cairo_surface_t *root_surface = cairo_xlib_surface_create(
      dpy, root_window, DefaultVisual(dpy, screen), w, h);
  cairo_xlib_surface_set_size(root_surface, w, h);
  assert(root_surface);

  // Tell cairo that surface is a cairo region
  cairo_t *cairo_region = cairo_create(root_surface);
  cairo_surface_destroy(root_surface);
  assert(cairo_region);

  // Create a surface with a png
  cairo_surface_t *image = cairo_image_surface_create_from_png(argv[1]);
  assert(image);

  // Tell cairo the new source for the surface
  cairo_set_source_surface(cairo_region, image, 0, 0);
  cairo_surface_destroy(image);

  // Listen for events in the window, in particular the ExposeEvent
  // and tell the window to redraw
  XSelectInput(dpy, root_window, ExposureMask);

  // Send the first event
  cairo_paint(cairo_region);

  pid_t child_pid = fork();
  if (child_pid == 0) {
    XEvent ev;
    for (;;) {
      XNextEvent(dpy, &ev);
      if (ev.type == Expose)
        // Paint the cairo region when needed
        cairo_paint(cairo_region);
    }
  }

  cairo_destroy(cairo_region);
  XCloseDisplay(dpy);
  exit(0);
}
