#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include <pthread.h>

#define MAX_URLS 100
#define MAX_URL_LEN 1024

static size_t write_data(void *ptr, size_t size, size_t nmemb, FILE *stream) {
    return fwrite(ptr, size, nmemb, stream);
}

static int progress_func(void *clientp,
                         curl_off_t dltotal, curl_off_t dlnow,
                         curl_off_t ultotal, curl_off_t ulnow)
{
    if (dltotal > 0) {
        int percent = (int)((dlnow * 100) / dltotal);
        printf("\rΚατεβάζει: %lld / %lld bytes (%d%%)", dlnow, dltotal, percent);
        fflush(stdout);
    }
    return 0;
}

// --- η για κατέβασμα ενός αρχείου ---
int download_file(const char *url, const char *output_filename) {
    CURL *curl;
    FILE *fp;
    CURLcode res;

    curl = curl_easy_init();
    if (!curl) {
        fprintf(stderr, "Αποτυχία αρχικοποίησης CURL.\n");
        return 1;
    }

    fp = fopen(output_filename, "wb");
    if (!fp) {
        perror("fopen");
        curl_easy_cleanup(curl);
        return 1;
    }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
    curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
    curl_easy_setopt(curl, CURLOPT_XFERINFOFUNCTION, progress_func);

    res = curl_easy_perform(curl);
    printf("\n");

    fclose(fp);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        fprintf(stderr, "Σφάλμα: %s\n", curl_easy_strerror(res));
        return 1;
    }

    return 0;
}

// --- Συνάρτηση για διάβασμα URLs από αρχείο ---
int read_urls_from_file(const char *filename, char urls[][MAX_URL_LEN], int *url_count) {
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        perror("fopen");
        return 1;
    }

    char buffer[MAX_URL_LEN];
    *url_count = 0;

    while (fgets(buffer, sizeof(buffer), fp)) {
        // Αφαίρεση newline
        buffer[strcspn(buffer, "\r\n")] = 0;

        if (strlen(buffer) > 0 && *url_count < MAX_URLS) {
            strncpy(urls[*url_count], buffer, MAX_URL_LEN - 1);
            urls[*url_count][MAX_URL_LEN - 1] = '\0'; // Ensure null-terminated
            (*url_count)++;
        }
    }

    fclose(fp);
    return 0;
}


typedef struct {
    char url[MAX_URL_LEN];
    char filename[MAX_URL_LEN];
} DownloadTask;

void *download_thread(void *arg) {
    DownloadTask *task = (DownloadTask *)arg;
    if (download_file(task->url, task->filename) != 0) {
        fprintf(stderr, "Αποτυχία στο κατέβασμα: %s\n", task->url);
    }
    free(task); // Επειδή το malloc έγινε στο main
    return NULL;
}

// --- Κυρίως πρόγραμμα ---
int main(void) {
    char urls[MAX_URLS][MAX_URL_LEN];
    int url_count = 0;

    if (read_urls_from_file("files", urls, &url_count) != 0) {
        fprintf(stderr, "Αποτυχία ανάγνωσης αρχείου URLs.\n");
        return 1;
    }

pthread_t threads[MAX_URLS];

for (int i = 0; i < url_count; i++) {
    const char *filename = strrchr(urls[i], '/');
    if (!filename || strlen(filename) <= 1) {
        fprintf(stderr, "Άκυρο URL: %s\n", urls[i]);
        continue;
    }
    filename++; 

    printf("Κατέβασμα: %s -> %s\n", urls[i], filename);

   
    DownloadTask *task = malloc(sizeof(DownloadTask));
    if (!task) {
        perror("malloc");
        continue;
    }
    strncpy(task->url, urls[i], MAX_URL_LEN);
    strncpy(task->filename, filename, MAX_URL_LEN);

    
    if (pthread_create(&threads[i], NULL, download_thread, task) != 0) {
        perror("pthread_create");
        free(task);
        continue;
    }
}


for (int i = 0; i < url_count; i++) {
    pthread_join(threads[i], NULL);
}

    return 0;
}
