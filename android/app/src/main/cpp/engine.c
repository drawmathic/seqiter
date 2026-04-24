#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#define MAX_B_MEMORY 2000000 
#define OVERFLOW_LIMIT 1000000000000000000ULL

// --- Previous math logic remains exactly the same ---
uint64_t compute_A(uint64_t b, uint64_t n) {
    if (b <= 1) return 0; 
    if (b > MAX_B_MEMORY) return OVERFLOW_LIMIT; 
    if (n == 0) return b;

    uint64_t digits[64];
    int k = 0;
    uint64_t temp = n;
    while (temp > 0) {
        digits[k++] = temp % b;
        temp /= b;
    }

    for (int i = 0; i < k / 2; i++) {
        uint64_t t = digits[i];
        digits[i] = digits[k - 1 - i];
        digits[k - 1 - i] = t;
    }

    uint64_t* current_counts = (uint64_t*)calloc(b, sizeof(uint64_t));
    uint64_t* next_counts = (uint64_t*)calloc(b, sizeof(uint64_t));
    
    if (!current_counts || !next_counts) {
        free(current_counts); free(next_counts);
        return OVERFLOW_LIMIT; 
    }

    for (uint64_t v = 0; v < b; v++) current_counts[v] = 1;

    for (int i = 0; i < k; i++) {
        uint64_t d = digits[i];
        memset(next_counts, 0, b * sizeof(uint64_t));

        for (uint64_t v = 0; v < b; v++) {
            if (current_counts[v] > 0) {
                if (v + d < b) next_counts[v + d] += current_counts[v];
                if (d != 0 && v >= d) next_counts[v - d] += current_counts[v];
            }
        }
        memcpy(current_counts, next_counts, b * sizeof(uint64_t));
    }

    uint64_t total = 0;
    for (uint64_t v = 0; v < b; v++) {
        total += current_counts[v];
        if (total > OVERFLOW_LIMIT) break;
    }

    free(current_counts);
    free(next_counts);
    return total;
}

int test_escape(uint64_t start_b, uint64_t s, int max_iter) {
    uint64_t tortoise = start_b;
    uint64_t hare = start_b;

    for (int i = 0; i < max_iter; i++) {
        tortoise = compute_A(tortoise, s);
        if (tortoise == 0 || tortoise >= OVERFLOW_LIMIT) return 1; 

        uint64_t h1 = compute_A(hare, s);
        if (h1 == 0 || h1 >= OVERFLOW_LIMIT) return 1;
        hare = compute_A(h1, s);
        if (hare == 0 || hare >= OVERFLOW_LIMIT) return 1;

        if (tortoise == hare) return 0; 
    }
    return 1; 
}

// 1. Initialize the BMP file with standard headers
EXPORT int32_t init_bmp(const char* filepath, int width, int height) {
    FILE *f = fopen(filepath, "wb");
    if (!f) return 0;

    int row_padded = (width * 3 + 3) & (~3);
    int filesize = 54 + row_padded * height;

    unsigned char bmpfileheader[14] = {'B','M', 0,0,0,0, 0,0, 0,0, 54,0,0,0};
    unsigned char bmpinfoheader[40] = {40,0,0,0, 0,0,0,0, 0,0,0,0, 1,0, 24,0};

    bmpfileheader[2] = (unsigned char)(filesize);
    bmpfileheader[3] = (unsigned char)(filesize>>8);
    bmpfileheader[4] = (unsigned char)(filesize>>16);
    bmpfileheader[5] = (unsigned char)(filesize>>24);

    bmpinfoheader[4] = (unsigned char)(width);
    bmpinfoheader[5] = (unsigned char)(width>>8);
    bmpinfoheader[6] = (unsigned char)(width>>16);
    bmpinfoheader[7] = (unsigned char)(width>>24);
    bmpinfoheader[8] = (unsigned char)(height);
    bmpinfoheader[9] = (unsigned char)(height>>8);
    bmpinfoheader[10] = (unsigned char)(height>>16);
    bmpinfoheader[11] = (unsigned char)(height>>24);

    fwrite(bmpfileheader, 1, 14, f);
    fwrite(bmpinfoheader, 1, 40, f);
    fclose(f);
    return 1;
}

// 2. Append calculated row chunks directly to the file
EXPORT int32_t append_bmp_rows(const char* filepath, int b_min, int b_max, int s_min, int s_max, int width, int height, int max_iter, int start_row, int num_rows) {
    FILE *f = fopen(filepath, "ab"); // Open in append mode
    if (!f) return 0;

    int row_padded = (width * 3 + 3) & (~3);
    unsigned char *row_data = (unsigned char *)calloc(row_padded, 1);

    for (int y = start_row; y < start_row + num_rows; y++) {
        uint64_t current_s = s_min + (uint64_t)y * (s_max - s_min) / height;
        for (int x = 0; x < width; x++) {
            uint64_t current_b = b_min + (uint64_t)x * (b_max - b_min) / width;
            
            int escaped = test_escape(current_b, current_s, max_iter);
            
            unsigned char color = escaped ? 255 : 0;
            row_data[x*3] = color;
            row_data[x*3+1] = color;
            row_data[x*3+2] = color;
        }
        fwrite(row_data, 1, row_padded, f);
    }

    free(row_data);
    fclose(f);
    return 1;
}
