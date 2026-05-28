#include <security/pam_appl.h>

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

    for (int i = 0; i < count; ++i) {
        free(responses[i].resp);
    }

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
    if (fgets(buffer, (int)buffer_size, stdin) == NULL)
        return -1;

    size_t length = strlen(buffer);

    while (length > 0 && (buffer[length - 1] == '\n' || buffer[length - 1] == '\r')) {
        buffer[length - 1] = '\0';
        length--;
    }

    return 0;
}

int
main(int argc, char **argv)
{
    const char *username;
    const char *service;
    char password[512];
    struct conv_data conv_data;
    struct pam_conv conv;
    pam_handle_t *pamh = NULL;
    int pam_status;

    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Usage: %s USER [SERVICE]\n", argv[0]);
        return 64;
    }

    if (geteuid() != 0) {
        fprintf(stderr, "Greeter auth helper must be run as root via mdo or doas.\n");
        return 126;
    }

    username = argv[1];
    service = argc >= 3 ? argv[2] : "login";

    if (read_password(password, sizeof(password)) != 0) {
        fprintf(stderr, "No password was provided to the greeter auth helper.\n");
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
    puts("Authentication successful.");
    return 0;
}
