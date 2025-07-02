#include <X11/X.h>
#include <X11/Xlib.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

int main(int argc, char **argv) {
  assert(argc == 2);
  Display *dpy = XOpenDisplay(NULL);
  int screen = XDefaultScreen(dpy);
  Window root = XRootWindow(dpy, screen);

  Pixmap pixmapfile;
  unsigned int width, height;

  if (XReadBitmapFile(dpy, root, argv[1], &width, &height, &pixmapfile,
                      (int *)NULL, (int *)NULL)) {
    printf("Bad file or no memory.");

    XFreePixmap(dpy, pixmapfile);
    XClearWindow(dpy, root);
    XCloseDisplay(dpy);

    return 1;
  }

  srand(time(NULL));
  // Needed to have the same depth.
  Pixmap pixmap = XCreatePixmap(dpy, root, width, height,
                                (unsigned int)XDefaultDepth(dpy, screen));

  XGCValues gc_init;
  gc_init.foreground = rand();
  gc_init.background = rand();

  GC gc = XCreateGC(dpy, root, GCForeground | GCBackground, &gc_init);

  XCopyPlane(dpy, pixmapfile, pixmap, gc, 0, 0, width, height, 0, 0,
             (unsigned long)1);

  XSetWindowBackgroundPixmap(dpy, root, pixmap);
  XClearWindow(dpy, root);

  XFreeGC(dpy, gc);
  XFreePixmap(dpy, pixmap);
  XFreePixmap(dpy, pixmapfile);
  XCloseDisplay(dpy);

  return 0;
}
