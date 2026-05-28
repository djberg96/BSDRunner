#include <sys/types.h>

#include <security/pam_appl.h>
#include <login_cap.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct conv_data {
    const char *password;
};

static void
free_pam_responses(struct pam_response *responses, int count)
{
    if (responses == NULL)
        return;

    for (int i = 0; i < count; ++i)
        free(responses[i].resp);

    free(responses);
}

static int
conversation(int num_msg, const struct pam_message **msg, struct pam_response **resp, void *appdata_ptr)
{
    struct conv_data *data = appdata_ptr;
    struct pam_response *responses = calloc((size_t)num_msg, sizeof(*responses));

    if (responses == NULL)
        return PAM_BUF_ERR;

    for (int i = 0; i < num_msg; ++i) {
        switch (msg[i]->msg_style) {
        case PAM_PROMPT_ECHO_OFF:
        case PAM_PROMPT_ECHO_ON:
            responses[i].resp = strdup(data->password != NULL ? data->password : "");
            if (responses[i].resp == NULL) {
                free_pam_responses(responses, num_msg);
                return PAM_BUF_ERR;
            }
            break;
        case PAM_ERROR_MSG:
        case PAM_TEXT_INFO:
            responses[i].resp = NULL;
            break;
        default:
            free_pam_responses(responses, num_msg);
            return PAM_CONV_ERR;
        }
    }

    *resp = responses;
    return PAM_SUCCESS;
}

static int
read_password(char *buffer, size_t buffer_size)
{
    size_t length;

    if (fgets(buffer, (int)buffer_size, stdin) == NULL)
        return -1;

    length = strlen(buffer);
    while (length > 0 && (buffer[length - 1] == '\n' || buffer[length - 1] == '\r')) {
        buffer[length - 1] = '\0';
        --length;
    }

    return 0;
}

static int
redirect_stdio_to_devnull(void)
{
    FILE *devnull = freopen("/dev/null", "r", stdin);

    if (devnull == NULL)
        return -1;
    if (freopen("/dev/null", "w", stdout) == NULL)
        return -1;
    if (freopen("/dev/null", "w", stderr) == NULL)
        return -1;

    return 0;
}

static int
launch_user_session(const char *username, const char *session_name)
{
    struct passwd *pwd;
    login_cap_t *lc;
    unsigned int flags;
    char session_script[4096];

    pwd = getpwnam(username);
    if (pwd == NULL) {
        fprintf(stderr, "No such account exists on this system.\n");
        return 5;
    }

    if (redirect_stdio_to_devnull() != 0)
        return 1;

    lc = login_getpwclass(pwd);
    flags = LOGIN_SETGROUP
        | LOGIN_SETUSER
        | LOGIN_SETRESOURCES
        | LOGIN_SETPRIORITY
        | LOGIN_SETUMASK
        | LOGIN_SETPATH
        | LOGIN_SETENV
        | LOGIN_SETLOGINCLASS;

    if (setusercontext(lc, pwd, pwd->pw_uid, flags) != 0) {
        if (lc != NULL)
            login_close(lc);
        return 1;
    }

    if (lc != NULL)
        login_close(lc);

    setenv("HOME", pwd->pw_dir, 1);
    setenv("USER", pwd->pw_name, 1);
    setenv("LOGNAME", pwd->pw_name, 1);
    setenv("SHELL", pwd->pw_shell != NULL && pwd->pw_shell[0] != '\0' ? pwd->pw_shell : "/bin/sh", 1);
    setenv("XDG_SESSION_TYPE", "wayland", 0);

    if (chdir(pwd->pw_dir) != 0)
        chdir("/");

    if (snprintf(session_script, sizeof(session_script), "%s/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh", pwd->pw_dir) >= (int)sizeof(session_script))
        return 1;

    execl("/bin/sh", "sh", session_script, session_name, (char *)NULL);
    return 1;
}

int
main(int argc, char **argv)
{
    const char *username;
    const char *session_name;
    const char *service;
    char password[512];
    struct conv_data conv_data;
    struct pam_conv conv;
    pam_handle_t *pamh = NULL;
    int pam_status;
    pid_t child_pid;

    if (argc < 3 || argc > 4) {
        fprintf(stderr, "Usage: %s USER SESSION [SERVICE]\n", argv[0]);
        return 64;
    }

    if (geteuid() != 0) {
        fprintf(stderr, "Greeter login helper must be run as root via mdo or doas.\n");
        return 126;
    }

    username = argv[1];
    session_name = argv[2];
    service = argc >= 4 ? argv[3] : "login";

    if (read_password(password, sizeof(password)) != 0) {
        fprintf(stderr, "No password was provided to the greeter login helper.\n");
        return 65;
    }

    conv_data.password = password;
    conv.conv = conversation;
    conv.appdata_ptr = &conv_data;

    pam_status = pam_start(service, username, &conv, &pamh);
    if (pam_status != PAM_SUCCESS) {
        fprintf(stderr, "Authentication could not begin for that account.\n");
        return 3;
    }

    pam_status = pam_authenticate(pamh, 0);
    if (pam_status != PAM_SUCCESS) {
        fprintf(stderr, "The supplied credentials were not accepted.\n");
        pam_end(pamh, pam_status);
        return 4;
    }

    pam_status = pam_acct_mgmt(pamh, 0);
    if (pam_status != PAM_SUCCESS && pam_status != PAM_NEW_AUTHTOK_REQD) {
        fprintf(stderr, "The account is not allowed to log in right now.\n");
        pam_end(pamh, pam_status);
        return 5;
    }

    pam_end(pamh, PAM_SUCCESS);

    child_pid = fork();
    if (child_pid < 0) {
        fprintf(stderr, "Failed to create the user session process.\n");
        return 1;
    }

    if (child_pid == 0)
        _exit(launch_user_session(username, session_name));

    printf("Authentication successful. Launching %s session for %s.\n", session_name, username);
    return 0;
}
