#include <stdio.h>
#include <X11/Xlib.h>
#include <X11/XKBlib.h>

int main(void)
{
    const char *labels[] = {"EN", "RU", "KZ"};
    Display *display = XOpenDisplay(NULL);
    XkbStateRec state;

    if (!display) {
        fputs("Не удалось открыть экран Xorg\n", stderr);
        return 1;
    }

    if (XkbGetState(display, XkbUseCoreKbd, &state) != Success) {
        XCloseDisplay(display);
        return 1;
    }

    puts(state.group < 3 ? labels[state.group] : "??");
    XCloseDisplay(display);
    return 0;
}
