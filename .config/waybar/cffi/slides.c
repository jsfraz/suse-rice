/* Digit slides for the bar. Clock digits move up/down, the workspace number moves sideways.
 * Rebuild: gcc -shared -fPIC -o libslides.so slides.c $(pkg-config --cflags --libs gtk+-3.0)
 */
#include <errno.h>
#include <langinfo.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

/* Linked against the system GTK that Waybar already uses. Declarations stand in
 * for the missing gtk3-devel headers. */
typedef struct _GtkWidget GtkWidget;
typedef struct _GtkContainer GtkContainer;
typedef struct _GtkStack GtkStack;
typedef struct _GtkBox GtkBox;
typedef struct _GtkStyleContext GtkStyleContext;
typedef struct _GIOChannel GIOChannel;

typedef struct {
    char *str;
    unsigned long len;
    unsigned long allocated_len;
} GString;

#define TRUE 1
#define FALSE 0
#define G_SOURCE_REMOVE 0

enum {
    GTK_ORIENTATION_HORIZONTAL = 0,
    GTK_ALIGN_CENTER = 3,
    GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT_RIGHT = 6,
    GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN = 7,
    G_IO_IN = 1,
    G_IO_ERR = 8,
    G_IO_HUP = 16,
    G_IO_NVAL = 32,
    G_IO_STATUS_NORMAL = 0,
    G_IO_FLAG_NONBLOCK = 2,
    G_SOURCE_CONTINUE = 1
};

GtkWidget *gtk_stack_new(void);
void gtk_stack_set_transition_type(GtkStack *stack, int type);
void gtk_stack_set_transition_duration(GtkStack *stack, unsigned int duration);
void gtk_stack_set_hhomogeneous(GtkStack *stack, int homogeneous);
void gtk_stack_set_vhomogeneous(GtkStack *stack, int homogeneous);
void gtk_stack_set_interpolate_size(GtkStack *stack, int interpolate_size);
void gtk_stack_add_named(GtkStack *stack, GtkWidget *child, const char *name);
void gtk_stack_set_visible_child_name(GtkStack *stack, const char *name);
const char *gtk_stack_get_visible_child_name(GtkStack *stack);
GtkWidget *gtk_stack_get_child_by_name(GtkStack *stack, const char *name);
GtkWidget *gtk_label_new(const char *str);
GtkWidget *gtk_box_new(int orientation, int spacing);
void gtk_box_pack_start(GtkBox *box, GtkWidget *child, int expand, int fill, unsigned int padding);
void gtk_widget_set_valign(GtkWidget *widget, int align);
void gtk_widget_set_halign(GtkWidget *widget, int align);
void gtk_widget_show(GtkWidget *widget);
void gtk_widget_show_all(GtkWidget *widget);
GtkStyleContext *gtk_widget_get_style_context(GtkWidget *widget);
void gtk_style_context_add_class(GtkStyleContext *context, const char *class_name);
void gtk_container_add(GtkContainer *container, GtkWidget *widget);
unsigned int g_timeout_add(unsigned int interval, int (*function)(void *), void *data);
int g_source_remove(unsigned int tag);
GString *g_string_new(const char *init);
GString *g_string_append_len(GString *string, const char *val, long len);
GString *g_string_erase(GString *string, long pos, long len);
void g_string_free(GString *string, int free_segment);
GIOChannel *g_io_channel_unix_new(int fd);
int g_io_channel_set_encoding(GIOChannel *channel, const char *encoding, void **error);
void g_io_channel_set_buffered(GIOChannel *channel, int buffered);
int g_io_channel_set_flags(GIOChannel *channel, int flags, void **error);
int g_io_channel_read_chars(GIOChannel *channel, char *buf, unsigned long count, unsigned long *bytes_read, void **error);
unsigned int g_io_add_watch(GIOChannel *channel, int condition, int (*func)(GIOChannel *, int, void *), void *user_data);
void g_io_channel_unref(GIOChannel *channel);

const size_t wbcffi_version = 1;

typedef struct wbcffi_module wbcffi_module;

typedef struct {
    wbcffi_module *obj;
    const char *waybar_version;
    GtkContainer *(*get_root_widget)(wbcffi_module *);
    void (*queue_update)(wbcffi_module *);
} wbcffi_init_info;

typedef struct {
    const char *key;
    const char *value;
} wbcffi_config_entry;

typedef struct {
    int clock;
    GtkWidget *weekday;
    GtkWidget *day;
    GtkWidget *month;
    GtkWidget *year[4];
    GtkWidget *digits[6];
    GtkWidget *workspace;
    unsigned int timer;
    unsigned int watch;
    int fd;
    GString *pending;
} SlideModule;

/* Filled from LC_TIME. DAY_1 is Sunday, matching tm_wday. MON_* is the
 * month form used inside a date (genitive in Czech, nominative in English). */
static char weekday_names[7][128];
static char month_names[12][128];
static const char *weekdays[7];
static const char *months[12];

static void copy_locale_name(char *dst, size_t len, nl_item item) {
    const char *name = nl_langinfo(item);
    if (name == NULL || name[0] == '\0')
        name = "?";
    snprintf(dst, len, "%s", name);
}

static void load_locale_names(void) {
    setlocale(LC_TIME, "");
    for (int i = 0; i < 7; i++) {
        copy_locale_name(weekday_names[i], sizeof weekday_names[i], DAY_1 + i);
        weekdays[i] = weekday_names[i];
    }
    for (int i = 0; i < 12; i++) {
        copy_locale_name(month_names[i], sizeof month_names[i], MON_1 + i);
        months[i] = month_names[i];
    }
}

static const int clock_index[6] = {0, 1, 3, 4, 6, 7};

static GtkWidget *new_stack(int transition, int homogeneous) {
    GtkWidget *stack = gtk_stack_new();
    gtk_stack_set_transition_type((GtkStack *)stack, transition);
    gtk_stack_set_transition_duration((GtkStack *)stack, 200);
    gtk_stack_set_hhomogeneous((GtkStack *)stack, homogeneous);
    gtk_stack_set_vhomogeneous((GtkStack *)stack, TRUE);
    gtk_stack_set_interpolate_size((GtkStack *)stack, FALSE);
    gtk_widget_set_valign(stack, GTK_ALIGN_CENTER);
    gtk_widget_set_halign(stack, GTK_ALIGN_CENTER);
    return stack;
}

static void add_named(GtkWidget *stack, const char *name) {
    GtkWidget *label = gtk_label_new(name);
    gtk_widget_set_halign(label, GTK_ALIGN_CENTER);
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER);
    gtk_stack_add_named((GtkStack *)stack, label, name);
}

static GtkWidget *digit_stack(int transition, int first, int count) {
    GtkWidget *stack = new_stack(transition, TRUE);
    for (int i = 0; i < count; i++) {
        char name[8];
        snprintf(name, sizeof name, "%d", first + i);
        add_named(stack, name);
    }
    return stack;
}

static GtkWidget *word_stack(int transition, const char *const *words, int count) {
    GtkWidget *stack = new_stack(transition, FALSE);
    for (int i = 0; i < count; i++)
        add_named(stack, words[i]);
    return stack;
}

static void pack(GtkWidget *box, GtkWidget *child) {
    gtk_box_pack_start((GtkBox *)box, child, FALSE, FALSE, 0);
}

static void pack_text(GtkWidget *box, const char *text) {
    GtkWidget *label = gtk_label_new(text);
    gtk_widget_set_valign(label, GTK_ALIGN_CENTER);
    pack(box, label);
}

static void show_named(GtkWidget *stack, const char *name) {
    if (name == NULL || name[0] == '\0')
        return;
    if (gtk_stack_get_child_by_name((GtkStack *)stack, name) == NULL) {
        add_named(stack, name);
        gtk_widget_show_all(stack);
    }
    const char *current = gtk_stack_get_visible_child_name((GtkStack *)stack);
    if (current == NULL || strcmp(current, name) != 0)
        gtk_stack_set_visible_child_name((GtkStack *)stack, name);
}

static void show_workspace_id(SlideModule *module, int id) {
    char name[16];
    if (id < 1)
        id = 1;
    snprintf(name, sizeof name, "%d", id);
    show_named(module->workspace, name);
}

static int read_active_workspace(void) {
    FILE *pipe = popen("hyprctl activeworkspace 2>/dev/null", "r");
    if (pipe == NULL)
        return 1;
    char line[256];
    int id = 1;
    while (fgets(line, sizeof line, pipe) != NULL) {
        int parsed = 0;
        if (sscanf(line, "workspace ID %d", &parsed) == 1) {
            id = parsed;
            break;
        }
    }
    pclose(pipe);
    return id;
}

static void apply_workspace_line(SlideModule *module, const char *line) {
    const char *payload = NULL;
    if (strncmp(line, "workspacev2>>", 13) == 0)
        payload = line + 13;
    else if (strncmp(line, "workspace>>", 11) == 0)
        payload = line + 11;
    if (payload == NULL)
        return;
    char token[64];
    snprintf(token, sizeof token, "%s", payload);
    char *comma = strchr(token, ',');
    if (comma != NULL)
        *comma = '\0';
    char *end = NULL;
    long id = strtol(token, &end, 10);
    if (end != token && *end == '\0')
        show_workspace_id(module, (int)id);
    else
        show_named(module->workspace, token);
}

static int hypr_event_socket(void) {
    const char *runtime = getenv("XDG_RUNTIME_DIR");
    const char *signature = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (runtime == NULL || signature == NULL)
        return -1;
    char path[512];
    snprintf(path, sizeof path, "%s/hypr/%s/.socket2.sock", runtime, signature);
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    if (fd < 0)
        return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof addr.sun_path, "%s", path);
    if (connect(fd, (struct sockaddr *)&addr, sizeof addr) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static int on_hypr_event(GIOChannel *channel, int condition, void *data) {
    SlideModule *module = data;
    if (condition & (G_IO_HUP | G_IO_ERR | G_IO_NVAL))
        return G_SOURCE_REMOVE;

    char buf[512];
    unsigned long read_len = 0;
    int status;
    do {
        status = g_io_channel_read_chars(channel, buf, sizeof buf, &read_len, NULL);
        if (read_len > 0)
            g_string_append_len(module->pending, buf, (long)read_len);
    } while (status == G_IO_STATUS_NORMAL && read_len == sizeof buf);

    for (;;) {
        char *newline = strchr(module->pending->str, '\n');
        if (newline == NULL)
            break;
        *newline = '\0';
        apply_workspace_line(module, module->pending->str);
        g_string_erase(module->pending, 0, (newline - module->pending->str) + 1);
    }
    return G_SOURCE_CONTINUE;
}

static int poll_workspace(void *data) {
    show_workspace_id(data, read_active_workspace());
    return G_SOURCE_CONTINUE;
}

static int tick_clock(void *data) {
    SlideModule *module = data;
    time_t now = time(NULL);
    struct tm local;
    localtime_r(&now, &local);

    show_named(module->weekday, weekdays[local.tm_wday]);
    show_named(module->month, months[local.tm_mon]);

    char day[8];
    snprintf(day, sizeof day, "%d", local.tm_mday);
    show_named(module->day, day);

    char year[8];
    snprintf(year, sizeof year, "%04d", local.tm_year + 1900);
    for (int i = 0; i < 4; i++) {
        char name[2] = {year[i], '\0'};
        show_named(module->year[i], name);
    }

    char text[16];
    strftime(text, sizeof text, "%H:%M:%S", &local);
    for (int i = 0; i < 6; i++) {
        char name[2] = {text[clock_index[i]], '\0'};
        show_named(module->digits[i], name);
    }
    return G_SOURCE_CONTINUE;
}

static const char *config_value(const wbcffi_config_entry *entries, size_t len, const char *key) {
    for (size_t i = 0; i < len; i++) {
        if (strcmp(entries[i].key, key) == 0)
            return entries[i].value;
    }
    return NULL;
}

static void *make_clock(GtkContainer *root) {
    load_locale_names();
    SlideModule *module = calloc(1, sizeof *module);
    module->clock = TRUE;
    module->fd = -1;

    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_style_context_add_class(gtk_widget_get_style_context(box), "slide-clock");
    gtk_widget_set_valign(box, GTK_ALIGN_CENTER);

    module->weekday = word_stack(GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN, weekdays, 7);
    module->day = digit_stack(GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN, 1, 31);
    gtk_stack_set_hhomogeneous((GtkStack *)module->day, FALSE);
    module->month = word_stack(GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN, months, 12);
    for (int i = 0; i < 4; i++)
        module->year[i] = digit_stack(GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN, 0, 10);

    pack(box, module->weekday);
    pack_text(box, " ");
    pack(box, module->day);
    pack_text(box, ". ");
    pack(box, module->month);
    pack_text(box, " ");
    for (int i = 0; i < 4; i++)
        pack(box, module->year[i]);
    pack_text(box, " ");

    for (int i = 0; i < 6; i++) {
        module->digits[i] = digit_stack(GTK_STACK_TRANSITION_TYPE_SLIDE_UP_DOWN, 0, 10);
        pack(box, module->digits[i]);
        if (i == 1 || i == 3)
            pack_text(box, ":");
    }

    tick_clock(module);
    gtk_container_add(root, box);
    gtk_widget_show_all(box);
    module->timer = g_timeout_add(100, tick_clock, module);
    return module;
}

static void *make_workspace(GtkContainer *root) {
    SlideModule *module = calloc(1, sizeof *module);
    module->fd = -1;
    module->pending = g_string_new(NULL);

    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
    gtk_style_context_add_class(gtk_widget_get_style_context(box), "slide-workspace");
    gtk_widget_set_valign(box, GTK_ALIGN_CENTER);

    module->workspace = digit_stack(GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT_RIGHT, 1, 10);
    gtk_box_pack_start((GtkBox *)box, module->workspace, FALSE, FALSE, 0);
    show_workspace_id(module, read_active_workspace());

    gtk_container_add(root, box);
    gtk_widget_show_all(box);

    module->fd = hypr_event_socket();
    if (module->fd >= 0) {
        GIOChannel *channel = g_io_channel_unix_new(module->fd);
        g_io_channel_set_encoding(channel, NULL, NULL);
        g_io_channel_set_buffered(channel, FALSE);
        g_io_channel_set_flags(channel, G_IO_FLAG_NONBLOCK, NULL);
        module->watch = g_io_add_watch(channel, G_IO_IN | G_IO_HUP | G_IO_ERR, on_hypr_event, module);
        g_io_channel_unref(channel);
    } else {
        module->timer = g_timeout_add(100, poll_workspace, module);
    }
    return module;
}

void *wbcffi_init(const wbcffi_init_info *info, const wbcffi_config_entry *entries, size_t len) {
    const char *kind = config_value(entries, len, "kind");
    GtkContainer *root = info->get_root_widget(info->obj);
    if (kind != NULL && strcmp(kind, "clock") == 0)
        return make_clock(root);
    if (kind != NULL && strcmp(kind, "workspace") == 0)
        return make_workspace(root);
    return NULL;
}

void wbcffi_deinit(void *instance) {
    SlideModule *module = instance;
    if (module == NULL)
        return;
    if (module->timer != 0)
        g_source_remove(module->timer);
    if (module->watch != 0)
        g_source_remove(module->watch);
    if (module->fd >= 0)
        close(module->fd);
    if (module->pending != NULL)
        g_string_free(module->pending, TRUE);
    free(module);
}
