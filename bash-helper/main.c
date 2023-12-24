#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    int process = fork();
    if (process < 0) {
        printf("Fork error\n");
    }
    if (process == 0) {
        char *exe_name = "/opt/homebrew/bin/tmux";
        char *params[]  = {"tmux", "refresh-client", NULL};
        int status = execv(exe_name, params);

        // snatched from https://stackoverflow.com/a/32142863
        /* char* arr[] = {"ls", "-l", "-R", "-a", NULL}; */
        /* int status = execv("/bin/ls", arr); */

        //on successful execution of cmd, this exit never appears
        printf("main.c: status:%d,errno:%d,error:%s\n", status, errno, strerror(errno));
    }
    /* sleep(100); */
}
