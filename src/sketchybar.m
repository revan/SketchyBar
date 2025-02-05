#include "bar_manager.h"
#include "workspace.h"
#include "event_loop.h"
#include "mach.h"
#include "mouse.h"
#include "message.h"
#include "power.h"
#include "wifi.h"
#include "misc/help.h"
#include <libgen.h>
#include "media.h"

#define LCFILE_PATH_FMT         "/tmp/%s_%s.lock"

#define CLIENT_OPT_LONG         "--message"
#define CLIENT_OPT_SHRT         "-m"

#define VERSION_OPT_LONG        "--version"
#define VERSION_OPT_SHRT        "-v"

#define CONFIG_OPT_LONG         "--config"
#define CONFIG_OPT_SHRT         "-c"

#define HELP_OPT_LONG           "--help"
#define HELP_OPT_SHRT           "-h"

#define MAJOR 2
#define MINOR 15
#define PATCH 2

extern CGError SLSRegisterNotifyProc(void* callback, uint32_t event, void* context);
extern int SLSMainConnectionID(void);
extern int RunApplicationEventLoop(void);

int g_connection;
CFTypeRef g_transaction;

struct bar_manager g_bar_manager;
struct event_loop g_event_loop;
struct mach_server g_mach_server;
void *g_workspace_context;

char g_name[256];
char g_config_file[4096];
char g_lock_file[MAXLEN];
bool g_volume_events;
bool g_brightness_events;
int64_t g_disable_capture = 0;

static int client_send_message(int argc, char **argv) {
  if (argc <= 1) {
    return EXIT_SUCCESS;
  }

  char *user = getenv("USER");
  if (!user) {
    error("sketchybar-msg: 'env USER' not set! abort..\n");
  }

  int message_length = argc;
  int argl[argc];

  for (int i = 1; i < argc; ++i) {
    argl[i] = strlen(argv[i]);
    message_length += argl[i] + 1;
  }

  char* message = malloc((sizeof(char) * (message_length + 1)));
  char* temp = message;

  for (int i = 1; i < argc; ++i) {
    memcpy(temp, argv[i], argl[i]);
    temp += argl[i];
    *temp++ = '\0';
  }
  *temp++ = '\0';

  char bs_name[256];
  snprintf(bs_name, 256, MACH_BS_NAME_FMT, g_name);

  char* rsp = mach_send_message(mach_get_bs_port(bs_name),
                                message,
                                message_length,
                                true                     );

  free(message);
  if (!rsp) return EXIT_SUCCESS;

  if (strlen(rsp) > 2 && rsp[1] == '!') {
    fprintf(stderr, "%s", rsp);
    return EXIT_FAILURE;
  } else {
    fprintf(stdout, "%s", rsp);
  }

  return EXIT_SUCCESS;
}

static void acquire_lockfile(void) {
  int handle = open(g_lock_file, O_CREAT | O_WRONLY, 0600);
  if (handle == -1) {
    error("%s: could not create lock-file! abort..\n", g_name);
  }

  struct flock lockfd = {
    .l_start  = 0,
    .l_len    = 0,
    .l_pid    = getpid(),
    .l_type   = F_WRLCK,
    .l_whence = SEEK_SET
  };

  if (fcntl(handle, F_SETLK, &lockfd) == -1) {
    error("%s: could not acquire lock-file... already running?\n", g_name);
  }
}

static bool get_config_file(char *restrict filename, char *restrict buffer, int buffer_size) {
  char *xdg_home = getenv("XDG_CONFIG_HOME");
  if (xdg_home && *xdg_home) {
    snprintf(buffer, buffer_size, "%s/%s/%s", xdg_home, g_name, filename);
    if (file_exists(buffer)) return true;
  }

  char *home = getenv("HOME");
  if (!home) return false;

  snprintf(buffer, buffer_size, "%s/.config/%s/%s", home, g_name, filename);
  if (file_exists(buffer)) return true;

  snprintf(buffer, buffer_size, "%s/.%s", home, filename);
  return file_exists(buffer);
}

static void exec_config_file(void) {
  if (!*g_config_file
    && !get_config_file("sketchybarrc", g_config_file, sizeof(g_config_file))) {
    printf("could not locate config file..\n");
    return;
  }

  if (!file_exists(g_config_file)) {
    printf("file '%s' does not exist..\n", g_config_file);
    return;
  }

  setenv("CONFIG_DIR", dirname(g_config_file), 1);

  if (!ensure_executable_permission(g_config_file)) {
    printf("could not set the executable permission bit for '%s'\n", g_config_file);
    return;
  }

  if (!fork_exec(g_config_file, NULL)) {
    printf("failed to execute file '%s'\n", g_config_file);
    return;
  }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline void init_misc_settings(void) {
  char *user = getenv("USER");
  if (!user) {
    error("%s: 'env USER' not set! abort..\n", g_name);
  }

  snprintf(g_lock_file, sizeof(g_lock_file), LCFILE_PATH_FMT, g_name, user);

  if (__builtin_available(macOS 13.0, *)) {
  } else {
    NSApplicationLoad();
  }

  signal(SIGCHLD, SIG_IGN);
  signal(SIGPIPE, SIG_IGN);
  CGSetLocalEventsSuppressionInterval(0.0f);
  CGEnableEventStateCombining(false);
  g_connection = SLSMainConnectionID();
  g_volume_events = false;
  g_brightness_events = false;
}
#pragma clang diagnostic pop

static void parse_arguments(int argc, char **argv) {
  if ((string_equals(argv[1], VERSION_OPT_LONG))
      || (string_equals(argv[1], VERSION_OPT_SHRT))) {
    fprintf(stdout, "sketchybar-v%d.%d.%d\n", MAJOR, MINOR, PATCH);
    exit(EXIT_SUCCESS);
  } else if ((string_equals(argv[1], HELP_OPT_LONG))
      || (string_equals(argv[1], HELP_OPT_SHRT))) {
    printf(help_str, argv[0]);
    exit(EXIT_SUCCESS);
  } else if ((string_equals(argv[1], CLIENT_OPT_LONG))
             || (string_equals(argv[1], CLIENT_OPT_SHRT))) {
    exit(client_send_message(argc-1, argv+1));
  } else if ((string_equals(argv[1], CONFIG_OPT_LONG))
             || (string_equals(argv[1], CONFIG_OPT_SHRT))) {
    if (argc < 3) {
      printf("[!] Error: Too few arguments for argument 'config'.\n");
    } else {
      char* path = realpath(argv[2], NULL);
      if (path) {
        snprintf(g_config_file, sizeof(g_config_file), "%s", path);
        free(path);
        return;
      }

      printf("[!] Error: Specified config file path invalid.\n");
    }
    exit(EXIT_FAILURE);
  }

  exit(client_send_message(argc, argv));
}

void system_events(uint32_t event, void* data, size_t data_length, void* context) {
  if (event == 1322) {
    g_disable_capture = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW_APPROX);
  } else if (event == 905) {
    g_disable_capture = -1;
  } else {
    g_disable_capture = 0;
  }
}

int main(int argc, char **argv) {
  snprintf(g_name, sizeof(g_name), "%s", basename(argv[0]));
  if (argc > 1) parse_arguments(argc, argv);

  if (is_root())
    error("%s: running as root is not allowed! abort..\n", g_name);

  init_misc_settings();
  acquire_lockfile();

  if (!event_loop_init(&g_event_loop))
    error("%s: could not initialize event_loop! abort..\n", g_name);

  SLSRegisterNotifyProc((void*)system_events, 904, NULL);
  SLSRegisterNotifyProc((void*)system_events, 905, NULL);
  SLSRegisterNotifyProc((void*)system_events, 1401, NULL);
  SLSRegisterNotifyProc((void*)system_events, 1508, NULL);
  SLSRegisterNotifyProc((void*)system_events, 1322, NULL);

  workspace_event_handler_init(&g_workspace_context);
  bar_manager_init(&g_bar_manager);

  event_loop_begin(&g_event_loop);
  mouse_begin();
  display_begin();
  workspace_event_handler_begin(&g_workspace_context);

  windows_freeze();
  bar_manager_begin(&g_bar_manager);
  windows_unfreeze();

  if (!mach_server_begin(&g_mach_server, mach_message_handler))
    error("%s: could not initialize daemon! abort..\n", g_name);

  begin_receiving_power_events();
  begin_receiving_network_events();
  initialize_media_events();

  exec_config_file();
  RunApplicationEventLoop();
  return 0;
}
