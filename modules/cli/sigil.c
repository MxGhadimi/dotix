/*
 * Examples:
 *   sigil --seed ddbaf2b45b15ad45 --dither 4 --style hollow
 *   sigil --seed ddbaf2b45b15ad45 --dither 8 --style hollow
 *   sigil --seed ddbaf2b45b15ad45 --dither 4 --style smooth
 *   sigil --seed ddbaf2b45b15ad45 --dither 8 --style smooth
 *   sigil --out ~/sigil.png --bookmark favorite
 *   sigil --favorites; sigil --replay 1; sigil --remove 1
 */

#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <zlib.h>

#define WIDTH 1200
#define HEIGHT 520
#define PIXELS (WIDTH * HEIGHT)
#define PNG_ROW_BYTES (1 + WIDTH * 4)
#define PATH_LEN 4096
#define HEX_DIGITS "0123456789abcdefABCDEF"

#define DEFAULT_POINTS 6000000
#define DEFAULT_OPACITY 220
#define DEFAULT_COLOR 0xcdc2b5u
#define DEFAULT_COLUMNS 48
#define DEFAULT_DITHER 4

#define SEARCH_CANDIDATES 20
#define SEARCH_STEPS 20000
#define SEARCH_SKIP 200
#define WARMUP_POINTS 100

static const int BAYER4[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
static const int BAYER8[64] = {
     0, 32,  8, 40,  2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44,  4, 36, 14, 46,  6, 38,
    60, 28, 52, 20, 62, 30, 54, 22,
     3, 35, 11, 43,  1, 33,  9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47,  7, 39, 13, 45,  5, 37,
    63, 31, 55, 23, 61, 29, 53, 21
};

enum { STYLE_HOLLOW = 0, STYLE_SMOOTH = 1 };
static const char *style_name(int style) { return style == STYLE_SMOOTH ? "smooth" : "hollow"; }


// ---- Helpers ---------------------------------------------------------------

static void fail(const char *message) {
    fprintf(stderr, "sigil: %s\n", message);
    exit(1);
}

static void *xalloc(size_t count, size_t size, int zeroed) {
    void *p = zeroed ? calloc(count, size) : malloc(count * size);
    if (!p) fail("out of memory");
    return p;
}

static int is_hex(const char *s, size_t length) {
    return strlen(s) == length && strspn(s, HEX_DIGITS) == length;
}

static void random_bytes(unsigned char *out, size_t size) {
    while (size) {
        ssize_t n = getrandom(out, size, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) fail("could not read system randomness");
        out += n;
        size -= (size_t)n;
    }
}

static long parse_number(const char *s, long min, long max) {
    char *end;
    errno = 0;
    long n = strtol(s, &end, 10);
    if (errno || !*s || *end || n < min || n > max) fail("numeric option out of range or invalid");
    return n;
}

static void put32(unsigned char *p, uint32_t v) {
    p[0] = (unsigned char)(v >> 24);
    p[1] = (unsigned char)(v >> 16);
    p[2] = (unsigned char)(v >> 8);
    p[3] = (unsigned char)v;
}

// ---- Random numbers --------------------------------------------------------

static uint64_t splitmix64(uint64_t *state) {
    uint64_t z = (*state += UINT64_C(0x9e3779b97f4a7c15));
    z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
    return z ^ (z >> 31);
}

static double random_coefficient(uint64_t *state) {
    double unit = (double)(splitmix64(state) >> 11) / 9007199254740991.0;
    return unit * 4.8 - 2.4;
}

// ---- Attractor -------------------------------------------------------------

typedef struct {
    double a, b, c, d;
    double minx, maxx, miny, maxy;
} attractor_t;

static void iterate(const attractor_t *t, double *x, double *y) {
    double nx = sin(t->a * *y) - cos(t->b * *x);
    double ny = sin(t->c * *x) - cos(t->d * *y);
    *x = nx;
    *y = ny;
}

static attractor_t find_attractor(uint64_t *state) {
    attractor_t best = {1.4, -2.3, 2.4, -2.1, -2, 2, -2, 2};
    double best_score = -1;

    for (int attempt = 0; attempt < SEARCH_CANDIDATES; attempt++) {
        attractor_t t;
        t.a = random_coefficient(state);
        t.b = random_coefficient(state);
        t.c = random_coefficient(state);
        t.d = random_coefficient(state);
        t.minx = t.miny = 9;
        t.maxx = t.maxy = -9;

        unsigned char visited[64 * 64] = {0};
        int cells = 0;
        double x = 0.1, y = 0.1;
        for (int i = 0; i < SEARCH_STEPS; i++) {
            iterate(&t, &x, &y);
            if (i < SEARCH_SKIP) continue;
            if (x < t.minx) t.minx = x;
            if (x > t.maxx) t.maxx = x;
            if (y < t.miny) t.miny = y;
            if (y > t.maxy) t.maxy = y;
            int gx = (int)((x + 2.01) * 64 / 4.02);
            int gy = (int)((y + 2.01) * 64 / 4.02);
            if (gx >= 0 && gx < 64 && gy >= 0 && gy < 64 && !visited[gy * 64 + gx]) {
                visited[gy * 64 + gx] = 1;
                cells++;
            }
        }

        double dx = t.maxx - t.minx, dy = t.maxy - t.miny;
        if (dx < 0.8 || dy < 0.8 || cells < 300) continue;
        double score = cells * sqrt(dx * dy);
        if (score > best_score) {
            best_score = score;
            best = t;
        }
    }
    return best;
}

static void splat(float *hits, double fx, double fy) {
    fx -= 0.5;
    fy -= 0.5;
    int x0 = (int)floor(fx), y0 = (int)floor(fy);
    double tx = fx - x0, ty = fy - y0;
    for (int sy = 0; sy < 2; sy++) {
        for (int sx = 0; sx < 2; sx++) {
            int px = x0 + sx, py = y0 + sy;
            if (px < 0 || px >= WIDTH || py < 0 || py >= HEIGHT) continue;
            double weight = (sx ? tx : 1 - tx) * (sy ? ty : 1 - ty);
            hits[(size_t)py * WIDTH + px] += (float)weight;
        }
    }
}

static void plot(const attractor_t *t, int points, float *hits) {
    double scale_x = WIDTH * 0.84 / (t->maxx - t->minx);
    double scale_y = HEIGHT * 0.84 / (t->maxy - t->miny);
    double scale = scale_x < scale_y ? scale_x : scale_y;
    double cx = WIDTH / 2.0 - (t->minx + t->maxx) * scale / 2.0;
    double cy = HEIGHT / 2.0 + (t->miny + t->maxy) * scale / 2.0;

    double x = 0.1, y = 0.1;
    for (int i = 0; i < points; i++) {
        iterate(t, &x, &y);
        if (i < WARMUP_POINTS) continue;
        splat(hits, cx + x * scale, cy - y * scale);
    }
}

// ---- Rendering -------------------------------------------------------------

static float select_kth(float *a, size_t n, size_t k) {
    size_t lo = 0, hi = n - 1;
    while (lo < hi) {
        float pivot = a[lo + (hi - lo) / 2];
        size_t i = lo, j = hi;
        while (i <= j) {
            while (a[i] < pivot) i++;
            while (a[j] > pivot) j--;
            if (i <= j) {
                float t = a[i];
                a[i] = a[j];
                a[j] = t;
                i++;
                if (j == 0) break;
                j--;
            }
        }
        if (k <= j) hi = j;
        else if (k >= i) lo = i;
        else break;
    }
    return a[k];
}

static double reference_density(const float *hits) {
    float *values = xalloc(PIXELS, sizeof *values, 0);
    size_t n = 0;
    for (size_t i = 0; i < PIXELS; i++) {
        if (hits[i] > 0.01f) values[n++] = hits[i];
    }
    double reference = 1.0;
    if (n) {
        reference = select_kth(values, n, (n * 95) / 100);
        if (reference < 1.0) reference = 1.0;
    }
    free(values);
    return reference;
}
static double bayer_threshold(int dither, int x, int y) {
    if (dither == 8) return (BAYER8[(y & 7) * 8 + (x & 7)] + 0.5) / 64.0;
    return (BAYER4[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0;
}

static void render(const float *hits, unsigned char *raw, unsigned int color, int opacity, int dither, int style, int width, int height) {
    const double log_peak = log1p(reference_density(hits));
    const size_t row_bytes = 1 + (size_t)width * 4;
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            double x0 = (double)x * WIDTH / width, x1 = (double)(x + 1) * WIDTH / width;
            double y0 = (double)y * HEIGHT / height, y1 = (double)(y + 1) * HEIGHT / height;
            double sum = 0.0;
            for (int sy = (int)y0; sy < (int)ceil(y1) && sy < HEIGHT; sy++) {
                double wy = fmin(y1, sy + 1.0) - fmax(y0, sy);
                for (int sx = (int)x0; sx < (int)ceil(x1) && sx < WIDTH; sx++) {
                    double wx = fmin(x1, sx + 1.0) - fmax(x0, sx);
                    sum += hits[(size_t)sy * WIDTH + sx] * wx * wy;
                }
            }
            double density = sum / ((x1 - x0) * (y1 - y0));
            if (density <= 0.01) continue;
            double tone = pow(log1p(density) / log_peak, style == STYLE_HOLLOW ? 0.85 : 1.0 / 1.35);
            unsigned char *pixel = raw + (size_t)y * row_bytes + 1 + x * 4;
            if (style == STYLE_SMOOTH) {
                double alpha = 65 + 45 * log1p(density);
                if (alpha > 220) alpha = 220;
                if (tone > 1.0) tone = 1.0;
                alpha = alpha * opacity / 220.0 * tone;
                alpha *= 0.92 + 0.16 * bayer_threshold(dither, x, y);
                pixel[3] = (unsigned char)(alpha < 0 ? 0 : alpha > 255 ? 255 : (int)(alpha + 0.5));
            } else {
                if (tone <= bayer_threshold(dither, x, y)) continue;
                int alpha = (int)(65 + 45 * log1p(density));
                pixel[3] = (unsigned char)((alpha < 220 ? alpha : 220) * opacity / 220);
            }
            pixel[0] = (unsigned char)(color >> 16);
            pixel[1] = (unsigned char)(color >> 8);
            pixel[2] = (unsigned char)color;
        }
    }
}

// ---- PNG and terminal output -----------------------------------------------

static void write_chunk(unsigned char **p, const char *type, const unsigned char *data, uint32_t length) {
    put32(*p, length);
    *p += 4;
    memcpy(*p, type, 4);
    *p += 4;
    if (length) {
        memcpy(*p, data, length);
        *p += length;
    }
    uLong crc = crc32(0L, Z_NULL, 0);
    crc = crc32(crc, (const Bytef *)type, 4);
    if (length) crc = crc32(crc, data, length);
    put32(*p, (uint32_t)crc);
    *p += 4;
}

static unsigned char *encode_png(const unsigned char *raw, size_t raw_len, size_t *out_len, int width, int height) {
    uLongf compressed_len = compressBound(raw_len);
    unsigned char *compressed = xalloc(compressed_len, 1, 0);
    if (compress2(compressed, &compressed_len, raw, raw_len, 1) != Z_OK) fail("PNG compression failed");

    size_t capacity = 8 + 25 + 12 + compressed_len + 12;
    unsigned char *png = xalloc(capacity, 1, 0);
    unsigned char *p = png;
    static const unsigned char signature[8] = {137, 80, 78, 71, 13, 10, 26, 10};
    memcpy(p, signature, 8);
    p += 8;

    unsigned char ihdr[13] = {0};
    put32(ihdr, (uint32_t)width);
    put32(ihdr + 4, (uint32_t)height);
    ihdr[8] = 8;
    ihdr[9] = 6;
    write_chunk(&p, "IHDR", ihdr, 13);
    write_chunk(&p, "IDAT", compressed, (uint32_t)compressed_len);
    write_chunk(&p, "IEND", NULL, 0);

    free(compressed);
    *out_len = (size_t)(p - png);
    return png;
}

static void make_parent_dirs(const char *path) {
    char dir[PATH_LEN];
    snprintf(dir, sizeof dir, "%s", path);
    for (char *p = dir + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(dir, 0755);
            *p = '/';
        }
    }
}

static void write_file(const char *path, const unsigned char *data, size_t len) {
    make_parent_dirs(path);
    FILE *f = fopen(path, "wb");
    if (!f) fail("could not open output file");
    if (fwrite(data, 1, len, f) != len || fclose(f) != 0) fail("could not write output file");
}

static char *base64_encode(const unsigned char *in, size_t n, size_t *out_len) {
    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    *out_len = 4 * ((n + 2) / 3);
    char *out = xalloc(*out_len + 1, 1, 0);
    size_t j = 0;
    for (size_t i = 0; i < n; i += 3) {
        uint32_t v = (uint32_t)in[i] << 16;
        if (i + 1 < n) v |= (uint32_t)in[i + 1] << 8;
        if (i + 2 < n) v |= in[i + 2];
        out[j++] = table[(v >> 18) & 63];
        out[j++] = table[(v >> 12) & 63];
        out[j++] = i + 1 < n ? table[(v >> 6) & 63] : '=';
        out[j++] = i + 2 < n ? table[v & 63] : '=';
    }
    out[j] = '\0';
    return out;
}

static void show_in_terminal(const unsigned char *png, size_t png_len, int max_columns, uint64_t seed) {
    size_t encoded_len;
    char *encoded = base64_encode(png, png_len, &encoded_len);

    struct winsize ws = {0};
    int columns = (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col) ? ws.ws_col : 80;
    int cols = columns - 2;
    if (cols < 1) cols = 1;
    if (cols > max_columns) cols = max_columns;

    for (size_t pos = 0; pos < encoded_len; pos += 4096) {
        size_t len = encoded_len - pos;
        if (len > 4096) len = 4096;
        int more = pos + len < encoded_len;
        if (pos == 0) printf("\033_Ga=T,f=100,c=%d,q=2,m=%d;", cols, more);
        else printf("\033_Gm=%d;", more);
        fwrite(encoded + pos, 1, len, stdout);
        fputs("\033\\", stdout);
    }
    printf("\n  (sigil) de jong attractor · seed %016" PRIx64, seed);
    free(encoded);
}

// ---- Favorites -------------------------------------------------------------
// Stored one per line as: <16 hex seed> <opacity> <RRGGBB> <points> <dither> <label>

typedef struct {
    uint64_t seed;
    int opacity, points, dither, style;
    unsigned int color;
    char label[128];
} favorite_t;

static void favorites_path(char *buf, size_t size) {
    const char *env = getenv("SIGIL_FAVORITES");
    if (env && *env) {
        snprintf(buf, size, "%s", env);
        return;
    }
    const char *home = getenv("HOME");
    if (!home || !*home) fail("HOME is not set; set SIGIL_FAVORITES instead");
    snprintf(buf, size, "%s/.local/share/sigil/favorites", home);
}

static int load_favorites(favorite_t **out) {
    char path[PATH_LEN];
    favorites_path(path, sizeof path);
    *out = NULL;

    FILE *f = fopen(path, "r");
    if (!f) return 0;

    int capacity = 16, count = 0;
    favorite_t *list = xalloc(capacity, sizeof *list, 0);
    char line[512];
    while (fgets(line, sizeof line, f)) {
        char hex[32] = "", color[32] = "", label[256] = "";
        int opacity = 0, points = 0, dither = DEFAULT_DITHER;
        if (sscanf(line, "%31s %d %31s %d %d %255[^\n]", hex, &opacity, color, &points, &dither, label) < 5) continue;
        if (dither != 4 && dither != 8) continue;
        if (!is_hex(hex, 16) || !is_hex(color, 6)) continue;

        if (count == capacity) {
            capacity *= 2;
            list = realloc(list, capacity * sizeof *list);
            if (!list) fail("out of memory");
        }
        favorite_t *fav = &list[count++];
        fav->seed = strtoull(hex, NULL, 16);
        fav->opacity = opacity;
        fav->points = points;
        fav->dither = dither;
        fav->style = dither == 8 ? STYLE_SMOOTH : STYLE_HOLLOW;
        const char *label_text = label;
        if (!strncmp(label, "@style=hollow ", 14)) { fav->style = STYLE_HOLLOW; label_text += 14; }
        else if (!strncmp(label, "@style=smooth ", 14)) { fav->style = STYLE_SMOOTH; label_text += 14; }
        fav->color = (unsigned int)strtoul(color, NULL, 16);
        snprintf(fav->label, sizeof fav->label, "%.127s", label_text);
    }
    fclose(f);
    *out = list;
    return count;
}

static void list_favorites(void) {
    favorite_t *list;
    int count = load_favorites(&list);
    char path[PATH_LEN];
    favorites_path(path, sizeof path);

    if (!count) {
        printf("no favorites yet (%s)\nadd one with: sigil --bookmark \"label\"\n", path);
        free(list);
        return;
    }
    printf("favorites (%s):\n", path);
    for (int i = 0; i < count; i++) {
        printf("  %2d) %016" PRIx64 "  opacity %3d  #%06x  points %8d  dither %d  style %s  %s\n",
               i + 1, list[i].seed, list[i].opacity, list[i].color, list[i].points, list[i].dither, style_name(list[i].style), list[i].label);
    }
    free(list);
}

static void remove_favorite(int number) {
    favorite_t *list;
    int count = load_favorites(&list);
    if (number > count) fail("no favorite with that number; see --favorites");

    char path[PATH_LEN];
    favorites_path(path, sizeof path);
    FILE *f = fopen(path, "w");
    if (!f) fail("could not write favorites file");
    for (int i = 0; i < count; i++) {
        if (i == number - 1) continue;
        fprintf(f, "%016" PRIx64 " %d %06x %d %d @style=%s %s\n", list[i].seed, list[i].opacity,
                list[i].color, list[i].points, list[i].dither, style_name(list[i].style), list[i].label);
    }
    if (fclose(f) != 0) fail("could not write favorites file");
    printf("removed #%d\n", number);
    free(list);
}

static void add_favorite(uint64_t seed, int opacity, unsigned int color, int points, int dither, int style, const char *label) {
    favorite_t *list;
    int count = load_favorites(&list);
    for (int i = 0; i < count; i++) {
        if (list[i].seed == seed && list[i].opacity == opacity && list[i].color == color &&
            list[i].points == points && list[i].dither == dither && list[i].style == style) {
            printf("already bookmarked as #%d\n", i + 1);
            free(list);
            return;
        }
    }
    free(list);

    char clean[128];
    snprintf(clean, sizeof clean, "%s", label);
    for (char *p = clean; *p; p++) {
        if (*p == '\n' || *p == '\r') *p = ' ';
    }

    char path[PATH_LEN];
    favorites_path(path, sizeof path);
    make_parent_dirs(path);
    FILE *f = fopen(path, "a");
    if (!f) fail("could not open favorites file");
    fprintf(f, "%016" PRIx64 " %d %06x %d %d @style=%s %s\n", seed, opacity, color, points, dither, style_name(style), clean);
    if (fclose(f) != 0) fail("could not write favorites file");
    printf("bookmarked as #%d (replay with: sigil --replay %d)\n", count + 1, count + 1);
}

// ---- Command line ----------------------------------------------------------

typedef struct {
    uint64_t seed;
    int has_seed;
    int opacity;
    int columns;
    int points;
    unsigned int color;
    int dither;
    int style;
    int replay;
    int show_favorites;
    int remove;
    const char *out_path;
    const char *bookmark_label;
} options_t;

static void usage(void) {
    puts("Usage: sigil [--seed HEX] [--opacity 0-255] [--color RRGGBB] [--width 1-200] [--points 10000-20000000]");
    puts("             [--dither 4|8] [--style hollow|smooth] [--out FILE.png] [--bookmark LABEL] [--replay N]");
    puts("             [--favorites] [--remove N]");
    puts("");
    puts("  --seed HEX        reproduce a sigil from its 16-digit hex seed (random by default)");
    puts("  --dither 4|8      Bayer matrix size (default: 4)");
    puts("  --style hollow|smooth  rendering appearance (default: hollow)");
    puts("  --out FILE.png    save the sigil as a PNG file (works without a terminal)");
    puts("  --bookmark LABEL  save this seed and settings to your favorites");
    puts("  --replay N        re-render favorite number N (see --favorites); flags after it override");
    puts("  --favorites       list saved favorites");
    puts("  --remove N        delete favorite number N");
    puts("");
    puts("Favorites file: $SIGIL_FAVORITES, or ~/.local/share/sigil/favorites");
}

static void apply_favorite(options_t *o, int number) {
    favorite_t *list;
    int count = load_favorites(&list);
    if (number > count) fail("no favorite with that number; see --favorites");
    const favorite_t *fav = &list[number - 1];
    o->seed = fav->seed;
    o->has_seed = 1;
    o->opacity = fav->opacity;
    o->color = fav->color;
    o->points = fav->points;
    o->dither = fav->dither;
    o->style = fav->style;
    free(list);
}

static options_t parse_args(int argc, char **argv) {
    options_t o = {
        .opacity = DEFAULT_OPACITY,
        .columns = DEFAULT_COLUMNS,
        .points = DEFAULT_POINTS,
        .color = DEFAULT_COLOR,
        .dither = DEFAULT_DITHER,
    };

    for (int i = 1; i + 1 < argc; i++) {
        if (!strcmp(argv[i], "--replay")) o.replay = (int)parse_number(argv[i + 1], 1, INT_MAX);
    }
    if (o.replay) apply_favorite(&o, o.replay);

    for (int i = 1; i < argc; i++) {
        const char *opt = argv[i];
        if (!strcmp(opt, "--help")) {
            usage();
            exit(0);
        }
        if (!strcmp(opt, "--favorites")) {
            o.show_favorites = 1;
            continue;
        }
        if (i + 1 >= argc) fail("option needs a value; use --help");
        const char *value = argv[++i];

        if (!strcmp(opt, "--seed")) {
            if (!is_hex(value, 16)) fail("seed must be exactly 16 hexadecimal digits");
            o.seed = strtoull(value, NULL, 16);
            o.has_seed = 1;
        } else if (!strcmp(opt, "--opacity")) {
            o.opacity = (int)parse_number(value, 0, 255);
        } else if (!strcmp(opt, "--width")) {
            o.columns = (int)parse_number(value, 1, 200);
        } else if (!strcmp(opt, "--points")) {
            o.points = (int)parse_number(value, 10000, 20000000);
        } else if (!strcmp(opt, "--color")) {
            if (!is_hex(value, 6)) fail("color must be RRGGBB");
            o.color = (unsigned int)strtoul(value, NULL, 16);
        } else if (!strcmp(opt, "--dither")) {
            if (strcmp(value, "4") && strcmp(value, "8")) fail("dither must be 4 or 8");
            o.dither = atoi(value);
        } else if (!strcmp(opt, "--style")) {
            if (!strcmp(value, "hollow")) o.style = STYLE_HOLLOW;
            else if (!strcmp(value, "smooth")) o.style = STYLE_SMOOTH;
            else fail("style must be hollow or smooth");
        } else if (!strcmp(opt, "--out")) {
            o.out_path = value;
        } else if (!strcmp(opt, "--bookmark")) {
            o.bookmark_label = value;
        } else if (!strcmp(opt, "--remove")) {
            o.remove = (int)parse_number(value, 1, INT_MAX);
        } else if (!strcmp(opt, "--replay")) {
          
        } else {
            fail("unknown option; use --help");
        }
    }
    return o;
}

// ---- Main ------------------------------------------------------------------

int main(int argc, char **argv) {
    options_t o = parse_args(argc, argv);

    if (o.show_favorites) {
        list_favorites();
        return 0;
    }
    if (o.remove) {
        remove_favorite(o.remove);
        return 0;
    }
    if (!o.out_path && !isatty(STDOUT_FILENO)) {
        fail("stdout is not a terminal; use --out FILE.png to save an image");
    }
    if (!o.has_seed) random_bytes((unsigned char *)&o.seed, sizeof o.seed);

    uint64_t rng = o.seed;
    attractor_t attractor = find_attractor(&rng);

    float *hits = xalloc(PIXELS, sizeof *hits, 1);
    plot(&attractor, o.points, hits);

    int image_width = WIDTH, image_height = HEIGHT;
    if (!o.out_path && isatty(STDOUT_FILENO)) {
        struct winsize ws = {0};
        if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 && ws.ws_col && ws.ws_xpixel) {
            int cols = (int)ws.ws_col - 2;
            if (cols < 1) cols = 1;
            if (cols > o.columns) cols = o.columns;
            int target = (int)lround((double)cols * ws.ws_xpixel / ws.ws_col);
            if (target >= 1 && target <= 4096) {
                image_width = target;
                image_height = (int)lround((double)target * HEIGHT / WIDTH);
                if (image_height < 1) image_height = 1;
            }
        }
    }
    const size_t raw_len = (size_t)image_height * (1 + (size_t)image_width * 4);
    unsigned char *raw = xalloc(raw_len, 1, 1);
    if (!o.out_path && o.style == STYLE_HOLLOW && (image_width != WIDTH || image_height != HEIGHT)) {
        int sw = image_width * 2, sh = image_height * 2;
        size_t source_row = 1 + (size_t)sw * 4;
        size_t target_row = 1 + (size_t)image_width * 4;
        unsigned char *super = xalloc((size_t)sh * source_row, 1, 1);
        render(hits, super, o.color, o.opacity, o.dither, o.style, sw, sh);
        render(hits, raw, o.color, o.opacity, o.dither, o.style, image_width, image_height);
        for (int y = 0; y < image_height; y++) {
            for (int x = 0; x < image_width; x++) {
                unsigned int alpha_sum = 0;
                for (int dy = 0; dy < 2; dy++)
                    for (int dx = 0; dx < 2; dx++)
                        alpha_sum += super[(size_t)(2*y + dy) * source_row + 1 + (2*x + dx)*4 + 3];
                unsigned char *pixel = raw + (size_t)y * target_row + 1 + x * 4;
                pixel[0] = (unsigned char)(o.color >> 16);
                pixel[1] = (unsigned char)(o.color >> 8);
                pixel[2] = (unsigned char)o.color;
                unsigned int smooth_alpha = (alpha_sum + 2) / 4;
                pixel[3] = (unsigned char)((35 * smooth_alpha + 65 * pixel[3] + 50) / 100);
            }
        }
        free(super);
    } else {
        render(hits, raw, o.color, o.opacity, o.dither, o.style, image_width, image_height);
    }
    free(hits);

    size_t png_len;
    unsigned char *png = encode_png(raw, raw_len, &png_len, image_width, image_height);
    free(raw);

    if (o.out_path) write_file(o.out_path, png, png_len);

    if (isatty(STDOUT_FILENO)) {
        show_in_terminal(png, png_len, o.columns, o.seed);
    } else {
        printf("(sigil) de jong attractor · seed %016" PRIx64 " · saved %s", o.seed, o.out_path);
    }
    free(png);

    if (o.bookmark_label) {
        add_favorite(o.seed, o.opacity, o.color, o.points, o.dither, o.style, o.bookmark_label);
    }
    return fflush(stdout) == 0 ? 0 : 1;
}
