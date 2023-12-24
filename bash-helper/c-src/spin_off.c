#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

void tmux_refresh_client() {
    int process = fork();
    if (process < 0) {
        printf("Fork error\n");
    }
    if (process == 0) {
        char *exe_name = "tmux";
        char *second_param = "refresh-client";
        char *params[]  = {exe_name, second_param, NULL};
        int status = execvp(exe_name, params);

        // snatched from https://stackoverflow.com/a/32142863
        /* char* arr[] = {"ls", "-l", "-R", "-a", NULL}; */
        /* int status = execv("/bin/ls", arr); */

        //on successful execution of cmd, this exit never appears
        printf("main.c: status:%d,errno:%d,error:%s\n", status, errno, strerror(errno));
    }
}
