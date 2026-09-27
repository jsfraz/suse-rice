/* Recolor tray-menu pixbufs so they match the item text.
 * Apps such as MEGAsync send gray PNGs, which ignore the CSS color property.
 *
 * The draw slot is the 19th function pointer in GtkWidgetClass on GTK 3.24.
 */

#include <glib-object.h>
#include <cairo.h>

typedef struct _GtkWidget GtkWidget;
typedef struct _GtkImage GtkImage;
typedef struct _GtkStyleContext GtkStyleContext;
typedef struct _GdkPixbuf GdkPixbuf;

typedef struct {
	double red;
	double green;
	double blue;
	double alpha;
} GdkRGBA;

typedef struct {
	GInitiallyUnownedClass parent_class;
	guint activate_signal;
	void (*fns[18])(void);
	gboolean (*draw)(GtkWidget *widget, cairo_t *cr);
} WidgetClassHead;

enum { GTK_IMAGE_PIXBUF = 1 };

static gboolean (*orig_draw)(GtkWidget *widget, cairo_t *cr);

GType gtk_image_get_type(void);
GType gtk_menu_get_type(void);
GType gtk_menu_item_get_type(void);
GtkWidget *gtk_widget_get_parent(GtkWidget *widget);
int gtk_image_get_storage_type(GtkImage *image);
GdkPixbuf *gtk_image_get_pixbuf(GtkImage *image);
gboolean gdk_pixbuf_get_has_alpha(const GdkPixbuf *pixbuf);
int gdk_pixbuf_get_n_channels(const GdkPixbuf *pixbuf);
int gdk_pixbuf_get_width(const GdkPixbuf *pixbuf);
int gdk_pixbuf_get_height(const GdkPixbuf *pixbuf);
int gdk_pixbuf_get_rowstride(const GdkPixbuf *pixbuf);
guchar *gdk_pixbuf_get_pixels(const GdkPixbuf *pixbuf);
GdkPixbuf *gdk_pixbuf_copy(const GdkPixbuf *pixbuf);
GtkStyleContext *gtk_widget_get_style_context(GtkWidget *widget);
int gtk_style_context_get_state(GtkStyleContext *context);
void gtk_style_context_get_color(GtkStyleContext *context, int state, GdkRGBA *color);
int gtk_widget_get_allocated_width(GtkWidget *widget);
int gtk_widget_get_allocated_height(GtkWidget *widget);
void gdk_cairo_set_source_pixbuf(cairo_t *cr, const GdkPixbuf *pixbuf, double x, double y);

static gboolean
in_menu(GtkWidget *widget)
{
	for (GtkWidget *parent = widget; parent != NULL; parent = gtk_widget_get_parent(parent)) {
		if (g_type_check_instance_is_a((GTypeInstance *)parent, gtk_menu_item_get_type()) ||
		    g_type_check_instance_is_a((GTypeInstance *)parent, gtk_menu_get_type()))
			return TRUE;
	}
	return FALSE;
}

static GdkPixbuf *
recolor(GdkPixbuf *src, const GdkRGBA *color)
{
	GdkPixbuf *dst = gdk_pixbuf_copy(src);
	if (dst == NULL)
		return NULL;

	int width = gdk_pixbuf_get_width(dst);
	int height = gdk_pixbuf_get_height(dst);
	int stride = gdk_pixbuf_get_rowstride(dst);
	int channels = gdk_pixbuf_get_n_channels(dst);
	guchar *pixels = gdk_pixbuf_get_pixels(dst);
	guchar red = (guchar)(color->red * 255.0 + 0.5);
	guchar green = (guchar)(color->green * 255.0 + 0.5);
	guchar blue = (guchar)(color->blue * 255.0 + 0.5);

	for (int y = 0; y < height; y++) {
		guchar *row = pixels + y * stride;
		for (int x = 0; x < width; x++) {
			guchar *pixel = row + x * channels;
			pixel[0] = red;
			pixel[1] = green;
			pixel[2] = blue;
		}
	}
	return dst;
}

static gboolean
image_draw(GtkWidget *widget, cairo_t *cr)
{
	if (!g_type_check_instance_is_a((GTypeInstance *)widget, gtk_image_get_type()) || !in_menu(widget))
		return orig_draw(widget, cr);

	GtkImage *image = (GtkImage *)widget;
	if (gtk_image_get_storage_type(image) != GTK_IMAGE_PIXBUF)
		return orig_draw(widget, cr);

	GdkPixbuf *pixbuf = gtk_image_get_pixbuf(image);
	if (pixbuf == NULL || !gdk_pixbuf_get_has_alpha(pixbuf) || gdk_pixbuf_get_n_channels(pixbuf) < 4)
		return orig_draw(widget, cr);

	GtkStyleContext *context = gtk_widget_get_style_context(widget);
	GdkRGBA color;
	gtk_style_context_get_color(context, gtk_style_context_get_state(context), &color);

	GdkPixbuf *colored = recolor(pixbuf, &color);
	if (colored == NULL)
		return orig_draw(widget, cr);

	int pix_w = gdk_pixbuf_get_width(colored);
	int pix_h = gdk_pixbuf_get_height(colored);
	double x = (gtk_widget_get_allocated_width(widget) - pix_w) / 2.0;
	double y = (gtk_widget_get_allocated_height(widget) - pix_h) / 2.0;

	gdk_cairo_set_source_pixbuf(cr, colored, x, y);
	cairo_paint(cr);
	g_object_unref(colored);
	return FALSE;
}

__attribute__((visibility("default"))) void
gtk_module_init(gint *argc, gchar ***argv)
{
	(void)argc;
	(void)argv;

	WidgetClassHead *klass = (WidgetClassHead *)g_type_class_ref(gtk_image_get_type());
	orig_draw = klass->draw;
	klass->draw = image_draw;
}
