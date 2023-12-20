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
        /* char *exe_name = "/opt/homebrew/opt/coreutils/libexec/gnubin/ls"; */
        /* char *arg0 = "refresh-client"; */
        char *arg0 = "-h\0";
        /* char *arg0 = "-alh"; */
        char **ptrptr = &arg0;
        printf("main.c: ptrptr: %s\n", *ptrptr);
        printf("main.c: argv: %s\n", *++argv);
        /* int status = execl(exe_name, arg0); */
        /* int status = execv(exe_name, ptrptr); */
        int status = execv(exe_name, *++argv);
        printf("main.c: Ran refresh: %d\n", status);

        printf("main.c: status:%d,errno:%d,error:%s\n", status, errno, strerror(errno));
    }
    /* sleep(100); */
}
