typedef void *HANDLE;
typedef void *HMODULE;
typedef unsigned long DWORD;
typedef unsigned short WCHAR;
typedef int BOOL;
typedef unsigned char BYTE;

#define GENERIC_READ 0x80000000UL
#define FILE_SHARE_READ 0x00000001UL
#define OPEN_EXISTING 3UL
#define FILE_ATTRIBUTE_NORMAL 0x00000080UL
#define STD_OUTPUT_HANDLE ((DWORD)-11)
#define INVALID_HANDLE_VALUE ((HANDLE)(long long)-1)

__declspec(dllimport) BOOL __stdcall SetDllDirectoryW(const WCHAR *);
__declspec(dllimport) HMODULE __stdcall LoadLibraryW(const WCHAR *);
__declspec(dllimport) void *__stdcall GetProcAddress(HMODULE, const char *);
__declspec(dllimport) HANDLE __stdcall CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
__declspec(dllimport) DWORD __stdcall GetFileSize(HANDLE, DWORD *);
__declspec(dllimport) BOOL __stdcall ReadFile(HANDLE, void *, DWORD, DWORD *, void *);
__declspec(dllimport) BOOL __stdcall CloseHandle(HANDLE);
__declspec(dllimport) DWORD __stdcall GetLastError(void);
__declspec(dllimport) HANDLE __stdcall GetStdHandle(DWORD);
__declspec(dllimport) BOOL __stdcall WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
__declspec(dllimport) void __stdcall ExitProcess(DWORD);
__declspec(dllimport) BOOL __stdcall FreeLibrary(HMODULE);

typedef unsigned long long u64;
typedef u64 (*ComputeCRC64Fn)(u64 seed, const void *data, u64 length);
typedef u64 (*CombineCRC64Fn)(u64 crc1, u64 crc2, u64 length2);

static unsigned char scratch[1048584] __attribute__((aligned(16)));
static char input[1048576];
static char output[512];

static void write_text(const char *s, unsigned long n) {
    DWORD wrote = 0;
    WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), s, n, &wrote, 0);
}

static unsigned long text_len(const char *s) {
    unsigned long n = 0;
    while (s[n]) ++n;
    return n;
}

static u64 parse_u64(const char *s) {
    u64 n = 0;
    unsigned base = 10;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        s += 2;
        base = 16;
    }
    while (*s) {
        unsigned d = *s >= '0' && *s <= '9' ? (unsigned)(*s - '0') :
                     *s >= 'a' && *s <= 'f' ? (unsigned)(*s - 'a' + 10) :
                     *s >= 'A' && *s <= 'F' ? (unsigned)(*s - 'A' + 10) : 99;
        if (d >= base) break;
        n = n * base + d;
        ++s;
    }
    return n;
}

static void append(char **p, const char *s) {
    while (*s) *(*p)++ = *s++;
}

static void append_hex(char **p, u64 n) {
    static const char digits[] = "0123456789abcdef";
    int i;
    for (i = 15; i >= 0; --i) *(*p)++ = digits[(n >> (i * 4)) & 15];
}

static void fill_pattern(const char *pattern, u64 offset, u64 length) {
    u64 i;
    for (i = 0; i < length; ++i) {
        u64 index = i;
        unsigned char b = 0;
        if (pattern[0] == 't') index += parse_u64(pattern + 4);
        if (pattern[0] == 'o') b = 0xff;
        else if (pattern[0] == 'r') b = (unsigned char)index;
        else if (pattern[0] == 'h') b = (index & 1) ? 0xff : 0x80;
        else if (pattern[0] == 'm') {
            static const unsigned char msg[] = "123456789";
            b = msg[index % 9];
        } else if (pattern[0] == 'p' || pattern[0] == 't')
            b = (unsigned char)(index * 37 + (index >> 3) * 11 + 0x80);
        scratch[offset + i] = b;
    }
}

static char *next_field(char **cursor) {
    char *s = *cursor;
    char *p = s;
    while (*p && *p != '\t' && *p != '\r' && *p != '\n') ++p;
    if (*p == '\t') { *p = 0; *cursor = p + 1; }
    else { if (*p) *p = 0; *cursor = p; }
    return s;
}

static void fail(const char *message, DWORD error) {
    char b[160];
    char *p = b;
    append(&p, "ERROR ");
    append(&p, message);
    append(&p, " win32=");
    {
        char rev[16];
        unsigned n = 0;
        do { rev[n++] = (char)('0' + error % 10); error /= 10; } while (error);
        while (n) *p++ = rev[--n];
    }
    *p++ = '\n';
    write_text(b, (unsigned long)(p - b));
    ExitProcess(2);
}

void mainCRTStartup(void) {
    static const WCHAR dll_path[] = L"Z:\\home\\violence\\Projects\\dji-studio-omarchy\\extracted\\1.0.0.30839\\alibabacloud-oss-cpp-sdk.dll";
    HANDLE file;
    DWORD size, got;
    HMODULE dll;
    ComputeCRC64Fn compute;
    CombineCRC64Fn combine;
    char *line;

    if (!SetDllDirectoryW(L"Z:\\home\\violence\\Projects\\dji-studio-omarchy\\extracted\\1.0.0.30839"))
        fail("SetDllDirectoryW", GetLastError());
    dll = LoadLibraryW(dll_path);
    if (!dll) fail("LoadLibraryW", GetLastError());
    compute = (ComputeCRC64Fn)GetProcAddress(dll, "?ComputeCRC64@OSS@AlibabaCloud@@YA_K_KPEAX0@Z");
    if (!compute) fail("GetProcAddress ComputeCRC64", GetLastError());
    combine = (CombineCRC64Fn)GetProcAddress(dll, "?CombineCRC64@OSS@AlibabaCloud@@YA_K_K00@Z");
    if (!combine) fail("GetProcAddress CombineCRC64", GetLastError());

    file = CreateFileW(L"cases.tsv", GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if (file == INVALID_HANDLE_VALUE) fail("CreateFileW cases.tsv", GetLastError());
    size = GetFileSize(file, 0);
    if (size >= sizeof(input)) fail("cases.tsv exceeds 1 MiB", size);
    if (!ReadFile(file, input, size, &got, 0) || got != size) fail("ReadFile cases.tsv", GetLastError());
    CloseHandle(file);

    line = input;
    while (*line) {
        char *next_line = line, *cursor = line, *kind, *id, *a, *b, *c, *d;
        char *out = output;
        u64 result;
        while (*next_line && *next_line != '\n') ++next_line;
        if (*next_line == '\n') ++next_line;
        kind = next_field(&cursor);
        id = next_field(&cursor);
        a = next_field(&cursor);
        b = next_field(&cursor);
        c = next_field(&cursor);
        d = next_field(&cursor);
        if (kind[0] == 'C') {
            u64 seed = parse_u64(a), offset = parse_u64(c), length = parse_u64(d);
            const void *ptr = 0;
            if (length) {
                fill_pattern(b, offset, length);
                ptr = scratch + offset;
            }
            result = compute(seed, ptr, length);
            append(&out, "C\t"); append(&out, id); append(&out, "\t");
            append_hex(&out, seed); append(&out, "\t"); append(&out, b);
            append(&out, "\t"); append(&out, c); append(&out, "\t"); append(&out, d);
            append(&out, "\t"); append_hex(&out, result); *out++ = '\n';
        } else if (kind[0] == 'B') {
            u64 crc1 = parse_u64(a), crc2 = parse_u64(b), length2 = parse_u64(c);
            result = combine(crc1, crc2, length2);
            append(&out, "B\t"); append(&out, id); append(&out, "\t");
            append_hex(&out, crc1); append(&out, "\t"); append_hex(&out, crc2);
            append(&out, "\t"); append(&out, c); append(&out, "\t");
            append_hex(&out, result); *out++ = '\n';
        } else fail("invalid case kind", 0);
        write_text(output, (unsigned long)(out - output));
        line = next_line;
    }
    FreeLibrary(dll);
    ExitProcess(0);
}
