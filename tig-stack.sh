#!/usr/bin/env bash

# edit these defaults here or edit them in an interactive menu when the script is run
INFLUXDB_GRAFANA_USER="safe"
INFLUXDB_GRAFANA_PASSWORD="jidjedewTSuIw4EmqhoOo"
INFLUXDB_TOKEN="HYdrv1bCZhsvMhYOq6_wg4NGV2OI9HZch_gh57nquSdAhbjhLMUIeYnCCAoybgJrJlLXRHUnDnz2v-xR0hDt3Q=="


export NEWT_COLORS='
window=,white
border=black,white
textbox=black,white
button=black,white
'

############################################## select TIG stack option action

SELECTION=$(whiptail --title "TIG Stack Setup" --radiolist \
"TIG Stack Setup Actions                              " 20 70 10 \
"1" "Install Telegraf" OFF \
"2" "Setup Influxdb2 & Grafana" OFF \
"3" "Install Docker Engine" OFF \
"4" "Exit" ON \
"5" "Stop & Uninstall TIG Stack" OFF 3>&1 1>&2 2>&3)

if [[ $? -eq 255 ]]; then
exit 0
fi

############################################################################################################################################### Install Telegraf
if [[ "$SELECTION" == "1" ]]; then

# stop Telegraf docker if running
docker compose --project-directory $HOME/.local/share/tig-stack/telegraf down

#remove old folders and config files if they exist 
sudo rm -rf $HOME/.local/share/tig-stack/telegraf

# enter the ipaddress and port of the influx instalation
INFLUXDB_IP_PORT=$(whiptail --title "IP address & Port of Influxdb2" --inputbox "\nIP address & Port of Influxdb2" 8 40 0.0.0.0:8086 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

# enter the token that will allow data to be writen to the influx DB
INFLUXDB_TOKEN=$(whiptail --title "Hostname for identification in Influxdb" --inputbox "\nInflux Token" 8 40 "HYdrv1bCZhsvMhYOq6_wg4NGV2OI9HZch_gh57nquSdAhbjhLMUIeYnCCAoybgJrJlLXRHUnDnz2v-xR0hDt3Q==" 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

## enter hostname which will be used as inlux label to identify which system the telegraf data comes from
HOSTNAME=$(whiptail --title "Hostname for identification in Influxdb" --inputbox "\nHostname for identification in Influxdb" 8 40 Hostname 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

#make Telegraf directory
mkdir -p $HOME/.local/share/tig-stack/telegraf

#create telegraf config file
tee $HOME/.local/share/tig-stack/telegraf/telegraf.conf 2>&1 > /dev/null <<EOF
# Configuration for telegraf agent
[agent]
  interval = "10s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "10s"
  flush_jitter = "0s"
  precision = ""
  hostname = "$HOSTNAME"
  omit_hostname = false
  
[[outputs.influxdb_v2]]
  urls = ["http://$INFLUXDB_IP_PORT"]
  token = "$INFLUXDB_TOKEN"
  organization = "safe-org"
  bucket = "telegraf"

########################################################## Monitors CPU
[[inputs.cpu]]
  percpu = false
  totalcpu = true
  collect_cpu_time = false
  report_active = false
  core_tags = false
  
######################################################### Read metrics about memory usage
[[inputs.mem]]
  # no configuration

######################################################### Monitors internet speed using speedtest.net service
[[inputs.internet_speed]]
  ## This plugin downloads many MB of data each time it is run. As such
  ## consider setting a higher interval for this plugin to reduce the
  ## demand on your internet connection.
  interval = "10m"

  ## Sets if runs file download test
  # enable_file_download = false

  ## Caches the closest server location
  # cache = false

########################################################### Read metrics about disk usage by mount point
[[inputs.disk]]
  ## By default stats will be gathered for all mount points.
  ## Set mount_points will restrict the stats to only the specified mount points.
  # mount_points = ["/"]

  ## Ignore mount points by filesystem type.
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

  ## Ignore mount points by mount options.
  ## The 'mount' command reports options of all mounts in parathesis.
  ## Bind mounts can be ignored with the special 'bind' option.
  # ignore_mount_opts = []

EOF


# write docker compose config file

tee $HOME/.local/share/tig-stack/telegraf/docker-compose.yaml 2>&1 > /dev/null <<EOF
version: "3.8"
services:

  telegraf:
    image: telegraf:1.29.5
    container_name: telegraf
    user: "1000:1000"
    volumes:
      # Make sure you create this local directory
      - $HOME/.local/share/tig-stack/telegraf/telegraf.conf:/etc/telegraf/telegraf.conf
    restart: unless-stopped
    networks:
      - tig_network

networks:
  tig_network:
    driver: bridge
EOF


# start telegraf docker and start loging tp influx 
docker compose --project-directory $HOME/.local/share/tig-stack/telegraf/ up

############################################################################################################################################ Setup Influxdb2 & Grafana
elif [[ "$SELECTION" == "2" ]]; then

## enter Admin username for Influx and Grafana
INFLUXDB_GRAFANA_USER=$(whiptail --title "Admin username for Influx & Grafana " --inputbox "\nAdmin username for Influx & Grafana" 8 40 $INFLUXDB_GRAFANA_USER 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

## enter Admin password for Influx and Grafana
INFLUXDB_GRAFANA_PASSWORD=$(whiptail --title "Admin password for Influx & Grafana " --inputbox "\nAdmin password for Influx & Grafana" 8 40 $INFLUXDB_GRAFANA_PASSWORD 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi

# enter the token that will allow data to be writen to the influx DB
INFLUXDB_TOKEN=$(whiptail --title "Hostname for identification in Influxdb" --inputbox "\nInflux Token" 8 40 "HYdrv1bCZhsvMhYOq6_wg4NGV2OI9HZch_gh57nquSdAhbjhLMUIeYnCCAoybgJrJlLXRHUnDnz2v-xR0hDt3Q==" 3>&1 1>&2 2>&3)
if [[ $? -eq 255 ]]; then
exit 0
fi


# stop Influxdb and grafana docker if running
docker compose --project-directory $HOME/.local/share/tig-stack/ down

#remove old folders and config files if they exists
sudo rm -rf $HOME/.local/share/tig-stack/grafana \
  $HOME/.local/share/tig-stack/influxdb

#make local directorys

mkdir -p $HOME/.local/share/tig-stack/influxdb/data \
  $HOME/.local/share/tig-stack/influxdb/config \
  $HOME/.local/share/tig-stack/grafana/data \
  $HOME/.local/share/tig-stack/grafana/config \
  $HOME/.local/share/tig-stack/grafana/log


##################################################################################write the influxdb.conf file leave this as it is for defaults
tee $HOME/.local/share/tig-stack/influxdb/config/config.yml 2>&1 > /dev/null <<EOF
assets-path: ""
bolt-path: /var/lib/influxdb2/influxd.bolt
e2e-testing: false
engine-path: /var/lib/influxdb2/engine
feature-flags: {}
flux-log-enabled: false
hardening-enabled: false
http-bind-address: :8086
http-idle-timeout: 3m0s
http-read-header-timeout: 10s
http-read-timeout: 0s
http-write-timeout: 0s
influxql-max-select-buckets: 0
influxql-max-select-point: 0
influxql-max-select-series: 0
instance-id: ""
key-name: ""
log-level: info
metrics-disabled: false
nats-max-payload-bytes: 0
no-tasks: false
pprof-disabled: false
query-concurrency: 1024
query-initial-memory-bytes: 0
query-max-memory-bytes: 0
query-memory-bytes: 0
query-queue-size: 1024
reporting-disabled: false
secret-store: bolt
session-length: 60
session-renew-disabled: false
sqlite-path: ""
storage-cache-max-memory-size: 1073741824
storage-cache-snapshot-memory-size: 26214400
storage-cache-snapshot-write-cold-duration: 10m0s
storage-compact-full-write-cold-duration: 4h0m0s
storage-compact-throughput-burst: 50331648
storage-max-concurrent-compactions: 0
storage-max-index-log-file-size: 1048576
storage-no-validate-field-size: false
storage-retention-check-interval: 30m0s
storage-series-file-max-concurrent-snapshot-compactions: 0
storage-series-id-set-cache-size: 0
storage-shard-precreator-advance-period: 30m0s
storage-shard-precreator-check-interval: 10m0s
storage-tsm-use-madv-willneed: false
storage-validate-keys: false
storage-wal-fsync-delay: 0s
storage-wal-max-concurrent-writes: 0
storage-wal-max-write-delay: 10m0s
storage-write-timeout: 10s
store: disk
testing-always-allow-setup: false
tls-cert: ""
tls-key: ""
tls-min-version: "1.2"
tls-strict-ciphers: false
tracing-type: ""
ui-disabled: false
vault-addr: ""
vault-cacert: ""
vault-capath: ""
vault-client-cert: ""
vault-client-key: ""
vault-client-timeout: 0s
vault-max-retries: 0
vault-skip-verify: false
vault-tls-server-name: ""
vault-token: ""
EOF

###################################################################################################################################################### write the grafana config

tee $HOME/.local/share/tig-stack/grafana/config/custom.ini 2>&1 > /dev/null <<EOF

##################### Grafana Configuration Example #####################
#
# Everything has defaults so you only need to uncomment things you want to
# change

# possible values : production, development
;app_mode = production

# instance name, defaults to HOSTNAME environment variable value or hostname if HOSTNAME var is empty
;instance_name = ${HOSTNAME}

# force migration will run migrations that might cause dataloss
# Deprecated, use clean_upgrade option in [unified_alerting.upgrade] instead.
;force_migration = false

#################################### Paths ####################################
[paths]
# Path to where grafana can store temp files, sessions, and the sqlite3 db (if that is used)
;data = /var/lib/grafana

# Temporary files in `data` directory older than given duration will be removed
;temp_data_lifetime = 24h

# Directory where grafana can store logs
;logs = /var/log/grafana

# Directory where grafana will automatically scan and look for plugins
;plugins = /var/lib/grafana/plugins

# folder that contains provisioning config files that grafana will apply on startup and while running.
;provisioning = conf/provisioning

#################################### Server ####################################
[server]
# Protocol (http, https, h2, socket)
;protocol = http

# This is the minimum TLS version allowed. By default, this value is empty. Accepted values are: TLS1.2, TLS1.3. If nothing is set TLS1.2 would be taken
;min_tls_version = ""

# The ip address to bind to, empty will bind to all interfaces
;http_addr =

# The http port  to use
;http_port = 3000

# The public facing domain name used to access grafana from a browser
;domain = localhost

# Redirect to correct domain if host header does not match domain
# Prevents DNS rebinding attacks
;enforce_domain = false

# The full public facing url you use in browser, used for redirects and emails
# If you use reverse proxy and sub path specify full url (with sub path)
;root_url = %(protocol)s://%(domain)s:%(http_port)s/

# Serve Grafana from subpath specified in `root_url` setting. By default it is set to `false` for compatibility reasons.
;serve_from_sub_path = false

# Log web requests
;router_logging = false

# the path relative working path
;static_root_path = public

# enable gzip
;enable_gzip = false

# https certs & key file
;cert_file =
;cert_key =

# Unix socket gid
# Changing the gid of a file without privileges requires that the target group is in the group of the process and that the process is the file owner
# It is recommended to set the gid as http server user gid
# Not set when the value is -1
;socket_gid =

# Unix socket mode
;socket_mode =

# Unix socket path
;socket =

# CDN Url
;cdn_url =

# Sets the maximum time using a duration format (5s/5m/5ms) before timing out read of an incoming request and closing idle connections.
# `0` means there is no timeout for reading the request.
;read_timeout = 0

# This setting enables you to specify additional headers that the server adds to HTTP(S) responses.
[server.custom_response_headers]
#exampleHeader1 = exampleValue1
#exampleHeader2 = exampleValue2

#################################### GRPC Server #########################
;[grpc_server]
;network = "tcp"
;address = "127.0.0.1:10000"
;use_tls = false
;cert_file =
;key_file =

#################################### Database ####################################
[database]
# You can configure the database connection by specifying type, host, name, user and password
# as separate properties or as on string using the url properties.

# Either "mysql", "postgres" or "sqlite3", it's your choice
;type = sqlite3
;host = 127.0.0.1:3306
;name = grafana
;user = root
# If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
;password =

# Use either URL or the previous fields to configure the database
# Example: mysql://user:secret@host:port/database
;url =

# For "postgres", use either "disable", "require" or "verify-full"
# For "mysql", use either "true", "false", or "skip-verify".
;ssl_mode = disable

# Database drivers may support different transaction isolation levels.
# Currently, only "mysql" driver supports isolation levels.
# If the value is empty - driver's default isolation level is applied.
# For "mysql" use "READ-UNCOMMITTED", "READ-COMMITTED", "REPEATABLE-READ" or "SERIALIZABLE".
;isolation_level =

;ca_cert_path =
;client_key_path =
;client_cert_path =
;server_cert_name =

# For "sqlite3" only, path relative to data_path setting
;path = grafana.db

# Max idle conn setting default is 2
;max_idle_conn = 2

# Max conn setting default is 0 (mean not set)
;max_open_conn =

# Connection Max Lifetime default is 14400 (means 14400 seconds or 4 hours)
;conn_max_lifetime = 14400

# Set to true to log the sql calls and execution times.
;log_queries =

# For "sqlite3" only. cache mode setting used for connecting to the database. (private, shared)
;cache_mode = private

# For "sqlite3" only. Enable/disable Write-Ahead Logging, https://sqlite.org/wal.html. Default is false.
;wal = false

# For "mysql" only if migrationLocking feature toggle is set. How many seconds to wait before failing to lock the database for the migrations, default is 0.
;locking_attempt_timeout_sec = 0

# For "sqlite" only. How many times to retry query in case of database is locked failures. Default is 0 (disabled).
;query_retries = 0

# For "sqlite" only. How many times to retry transaction in case of database is locked failures. Default is 5.
;transaction_retries = 5

# Set to true to add metrics and tracing for database queries.
;instrument_queries = false

################################### Data sources #########################
[datasources]
# Upper limit of data sources that Grafana will return. This limit is a temporary configuration and it will be deprecated when pagination will be introduced on the list data sources API.
;datasource_limit = 5000

#################################### Cache server #############################
[remote_cache]
# Either "redis", "memcached" or "database" default is "database"
;type = database

# cache connectionstring options
# database: will use Grafana primary database.
# redis: config like redis server e.g. `addr=127.0.0.1:6379,pool_size=100,db=0,ssl=false`. Only addr is required. ssl may be 'true', 'false', or 'insecure'.
# memcache: 127.0.0.1:11211
;connstr =

# prefix prepended to all the keys in the remote cache
; prefix =

# This enables encryption of values stored in the remote cache
;encryption =

#################################### Data proxy ###########################
[dataproxy]

# This enables data proxy logging, default is false
;logging = false

# How long the data proxy waits to read the headers of the response before timing out, default is 30 seconds.
# This setting also applies to core backend HTTP data sources where query requests use an HTTP client with timeout set.
;timeout = 30

# How long the data proxy waits to establish a TCP connection before timing out, default is 10 seconds.
;dialTimeout = 10

# How many seconds the data proxy waits before sending a keepalive probe request.
;keep_alive_seconds = 30

# How many seconds the data proxy waits for a successful TLS Handshake before timing out.
;tls_handshake_timeout_seconds = 10

# How many seconds the data proxy will wait for a server's first response headers after
# fully writing the request headers if the request has an "Expect: 100-continue"
# header. A value of 0 will result in the body being sent immediately, without
# waiting for the server to approve.
;expect_continue_timeout_seconds = 1

# Optionally limits the total number of connections per host, including connections in the dialing,
# active, and idle states. On limit violation, dials will block.
# A value of zero (0) means no limit.
;max_conns_per_host = 0

# The maximum number of idle connections that Grafana will keep alive.
;max_idle_connections = 100

# How many seconds the data proxy keeps an idle connection open before timing out.
;idle_conn_timeout_seconds = 90

# If enabled and user is not anonymous, data proxy will add X-Grafana-User header with username into the request, default is false.
;send_user_header = false

# Limit the amount of bytes that will be read/accepted from responses of outgoing HTTP requests.
;response_limit = 0

# Limits the number of rows that Grafana will process from SQL data sources.
;row_limit = 1000000

# Sets a custom value for the `User-Agent` header for outgoing data proxy requests. If empty, the default value is `Grafana/<BuildVersion>` (for example `Grafana/9.0.0`).
;user_agent =

#################################### Analytics ####################################
[analytics]
# Server reporting, sends usage counters to stats.grafana.org every 24 hours.
# No ip addresses are being tracked, only simple counters to track
# running instances, dashboard and error counts. It is very helpful to us.
# Change this option to false to disable reporting.
;reporting_enabled = true

# The name of the distributor of the Grafana instance. Ex hosted-grafana, grafana-labs
;reporting_distributor = grafana-labs

# Set to false to disable all checks to https://grafana.com
# for new versions of grafana. The check is used
# in some UI views to notify that a grafana update exists.
# This option does not cause any auto updates, nor send any information
# only a GET request to https://grafana.com/api/grafana/versions/stable to get the latest version.
;check_for_updates = true

# Set to false to disable all checks to https://grafana.com
# for new versions of plugins. The check is used
# in some UI views to notify that a plugin update exists.
# This option does not cause any auto updates, nor send any information
# only a GET request to https://grafana.com to get the latest versions.
;check_for_plugin_updates = true

# Google Analytics universal tracking code, only enabled if you specify an id here
;google_analytics_ua_id =

# Google Analytics 4 tracking code, only enabled if you specify an id here
;google_analytics_4_id =

# When Google Analytics 4 Enhanced event measurement is enabled, we will try to avoid sending duplicate events and let Google Analytics 4 detect navigation changes, etc.
;google_analytics_4_send_manual_page_views = false

# Google Tag Manager ID, only enabled if you specify an id here
;google_tag_manager_id =

# Rudderstack write key, enabled only if rudderstack_data_plane_url is also set
;rudderstack_write_key =

# Rudderstack data plane url, enabled only if rudderstack_write_key is also set
;rudderstack_data_plane_url =

# Rudderstack SDK url, optional, only valid if rudderstack_write_key and rudderstack_data_plane_url is also set
;rudderstack_sdk_url =

# Rudderstack Config url, optional, used by Rudderstack SDK to fetch source config
;rudderstack_config_url =

# Rudderstack Integrations URL, optional. Only valid if you pass the SDK version 1.1 or higher
;rudderstack_integrations_url =

# Intercom secret, optional, used to hash user_id before passing to Intercom via Rudderstack
;intercom_secret =

# Controls if the UI contains any links to user feedback forms
;feedback_links_enabled = true

#################################### Security ####################################
[security]
# disable creation of admin user on first start of grafana
;disable_initial_admin_creation = false

# default admin user, created on startup
admin_user = "$INFLUXDB_GRAFANA_USER"

# default admin password, can be changed before first start of grafana,  or in profile settings
admin_password = "$INFLUXDB_GRAFANA_PASSWORD"

# default admin email, created on startup
;admin_email = admin@localhost

# used for signing
;secret_key = SW2YcwTIb9zpOOhoPsMm

# current key provider used for envelope encryption, default to static value specified by secret_key
;encryption_provider = secretKey.v1

# list of configured key providers, space separated (Enterprise only)query: e.g., awskms.v1 azurekv.v1
;available_encryption_providers =

# disable gravatar profile images
;disable_gravatar = false

# data source proxy whitelist (ip_or_domain:port separated by spaces)
;data_source_proxy_whitelist =

# disable protection against brute force login attempts
;disable_brute_force_login_protection = false

# set to true if you host Grafana behind HTTPS. default is false.
;cookie_secure = false

# set cookie SameSite attribute. defaults to `lax`. can be set to "lax", "strict", "none" and "disabled"
;cookie_samesite = lax

# set to true if you want to allow browsers to render Grafana in a <frame>, <iframe>, <embed> or <object>. default is false.
;allow_embedding = false

# Set to true if you want to enable http strict transport security (HSTS) response header.
# HSTS tells browsers that the site should only be accessed using HTTPS.
;strict_transport_security = false

# Sets how long a browser should cache HSTS. Only applied if strict_transport_security is enabled.
;strict_transport_security_max_age_seconds = 86400

# Set to true if to enable HSTS preloading option. Only applied if strict_transport_security is enabled.
;strict_transport_security_preload = false

# Set to true if to enable the HSTS includeSubDomains option. Only applied if strict_transport_security is enabled.
;strict_transport_security_subdomains = false

# Set to true to enable the X-Content-Type-Options response header.
# The X-Content-Type-Options response HTTP header is a marker used by the server to indicate that the MIME types advertised
# in the Content-Type headers should not be changed and be followed.
;x_content_type_options = true

# Set to true to enable the X-XSS-Protection header, which tells browsers to stop pages from loading
# when they detect reflected cross-site scripting (XSS) attacks.
;x_xss_protection = true

# Enable adding the Content-Security-Policy header to your requests.
# CSP allows to control resources the user agent is allowed to load and helps prevent XSS attacks.
;content_security_policy = false

# Set Content Security Policy template used when adding the Content-Security-Policy header to your requests.
# $NONCE in the template includes a random nonce.
# $ROOT_PATH is server.root_url without the protocol.
;content_security_policy_template = """script-src 'self' 'unsafe-eval' 'unsafe-inline' 'strict-dynamic' $NONCE;object-src 'none';font-src 'self';style-src 'self' 'unsafe-inline' blob:;img-src * data:;base-uri 'self';connect-src 'self' grafana.com ws://$ROOT_PATH wss://$ROOT_PATH;manifest-src 'self';media-src 'none';form-action 'self';"""

# Enable adding the Content-Security-Policy-Report-Only header to your requests.
# Allows you to monitor the effects of a policy without enforcing it.
;content_security_policy_report_only = false

# Set Content Security Policy Report Only template used when adding the Content-Security-Policy-Report-Only header to your requests.
# $NONCE in the template includes a random nonce.
# $ROOT_PATH is server.root_url without the protocol.
;content_security_policy_report_only_template = """script-src 'self' 'unsafe-eval' 'unsafe-inline' 'strict-dynamic' $NONCE;object-src 'none';font-src 'self';style-src 'self' 'unsafe-inline' blob:;img-src * data:;base-uri 'self';connect-src 'self' grafana.com ws://$ROOT_PATH wss://$ROOT_PATH;manifest-src 'self';media-src 'none';form-action 'self';"""
# Controls if old angular plugins are supported or not. This will be disabled by default in future release
;angular_support_enabled = true

# List of additional allowed URLs to pass by the CSRF check, separated by spaces. Suggested when authentication comes from an IdP.
;csrf_trusted_origins = example.com

# List of allowed headers to be set by the user, separated by spaces. Suggested to use for if authentication lives behind reverse proxies.
;csrf_additional_headers =

# The CSRF check will be executed even if the request has no login cookie.
;csrf_always_check = false

# Comma-separated list of plugins ids that won't be loaded inside the frontend sandbox
;disable_frontend_sandbox_for_plugins =

[security.encryption]
# Defines the time-to-live (TTL) for decrypted data encryption keys stored in memory (cache).
# Please note that small values may cause performance issues due to a high frequency decryption operations.
;data_keys_cache_ttl = 15m

# Defines the frequency of data encryption keys cache cleanup interval.
# On every interval, decrypted data encryption keys that reached the TTL are removed from the cache.
;data_keys_cache_cleanup_interval = 1m

#################################### Snapshots ###########################
[snapshots]
# set to false to remove snapshot functionality
;enabled = true

# snapshot sharing options
;external_enabled = true
;external_snapshot_url = https://snapshots.raintank.io
;external_snapshot_name = Publish to snapshots.raintank.io

# Set to true to enable this Grafana instance act as an external snapshot server and allow unauthenticated requests for
# creating and deleting snapshots.
;public_mode = false

# remove expired snapshot
;snapshot_remove_expired = true

#################################### Dashboards History ##################
[dashboards]
# Number dashboard versions to keep (per dashboard). Default: 20, Minimum: 1
;versions_to_keep = 20

# Minimum dashboard refresh interval. When set, this will restrict users to set the refresh interval of a dashboard lower than given interval. Per default this is 5 seconds.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;min_refresh_interval = 5s

# Path to the default home dashboard. If this value is empty, then Grafana uses StaticRootPath + "dashboards/home.json"
;default_home_dashboard_path =

#################################### Users ###############################
[users]
# disable user signup / registration
;allow_sign_up = true

# Allow non admin users to create organizations
;allow_org_create = true

# Set to true to automatically assign new users to the default organization (id 1)
;auto_assign_org = true

# Set this value to automatically add new users to the provided organization (if auto_assign_org above is set to true)
;auto_assign_org_id = 1

# Default role new users will be automatically assigned
;auto_assign_org_role = Viewer

# Require email validation before sign up completes
;verify_email_enabled = false

# Background text for the user field on the login page
;login_hint = email or username
;password_hint = password

# Default UI theme ("dark" or "light")
;default_theme = dark

# Default UI language (supported IETF language tag, such as en-US)
;default_language = en-US

# Path to a custom home page. Users are only redirected to this if the default home dashboard is used. It should match a frontend route and contain a leading slash.
;home_page =

# External user management, these options affect the organization users view
;external_manage_link_url =
;external_manage_link_name =
;external_manage_info =

# Viewers can edit/inspect dashboard settings in the browser. But not save the dashboard.
;viewers_can_edit = false

# Editors can administrate dashboard, folders and teams they create
;editors_can_admin = false

# The duration in time a user invitation remains valid before expiring. This setting should be expressed as a duration. Examples: 6h (hours), 2d (days), 1w (week). Default is 24h (24 hours). The minimum supported duration is 15m (15 minutes).
;user_invite_max_lifetime_duration = 24h

# Enter a comma-separated list of users login to hide them in the Grafana UI. These users are shown to Grafana admins and themselves.
; hidden_users =

[secretscan]
# Enable secretscan feature
;enabled = false

# Interval to check for token leaks
;interval = 5m

# base URL of the grafana token leak check service
;base_url = https://secret-scanning.grafana.net

# URL to send outgoing webhooks to in case of detection
;oncall_url =

# Whether to revoke the token if a leak is detected or just send a notification
;revoke = true

[service_accounts]
# Service account maximum expiration date in days.
# When set, Grafana will not allow the creation of tokens with expiry greater than this setting.
; token_expiration_day_limit =

[auth]
# Login cookie name
;login_cookie_name = grafana_session

# Disable usage of Grafana build-in login solution.
;disable_login = false

# The maximum lifetime (duration) an authenticated user can be inactive before being required to login at next visit. Default is 7 days (7d). This setting should be expressed as a duration, e.g. 5m (minutes), 6h (hours), 10d (days), 2w (weeks), 1M (month). The lifetime resets at each successful token rotation.
;login_maximum_inactive_lifetime_duration =

# The maximum lifetime (duration) an authenticated user can be logged in since login time before being required to login. Default is 30 days (30d). This setting should be expressed as a duration, e.g. 5m (minutes), 6h (hours), 10d (days), 2w (weeks), 1M (month).
;login_maximum_lifetime_duration =

# How often should auth tokens be rotated for authenticated users when being active. The default is each 10 minutes.
;token_rotation_interval_minutes = 10

# Set to true to disable (hide) the login form, useful if you use OAuth, defaults to false
;disable_login_form = false

# Set to true to disable the sign out link in the side menu. Useful if you use auth.proxy or auth.jwt, defaults to false
;disable_signout_menu = false

# URL to redirect the user to after sign out
;signout_redirect_url =

# Set to true to attempt login with OAuth automatically, skipping the login screen.
# This setting is ignored if multiple OAuth providers are configured.
# Deprecated, use auto_login option for specific provider instead.
;oauth_auto_login = false

# OAuth state max age cookie duration in seconds. Defaults to 600 seconds.
;oauth_state_cookie_max_age = 600

# Skip forced assignment of OrgID 1 or 'auto_assign_org_id' for social logins
# Deprecated, use skip_org_role_sync option for specific provider instead.
;oauth_skip_org_role_update_sync = false

# limit of api_key seconds to live before expiration
;api_key_max_seconds_to_live = -1

# Set to true to enable SigV4 authentication option for HTTP-based datasources.
;sigv4_auth_enabled = false

# Set to true to enable verbose logging of SigV4 request signing
;sigv4_verbose_logging = false

# Set to true to enable Azure authentication option for HTTP-based datasources.
;azure_auth_enabled = false

# Set to skip the organization role from JWT login and use system's role assignment instead.
; skip_org_role_sync = false

# Use email lookup in addition to the unique ID provided by the IdP
;oauth_allow_insecure_email_lookup = false

# Set to true to include id of identity as a response header
;id_response_header_enabled = false

# Prefix used for the id response header, X-Grafana-Identity-Id
;id_response_header_prefix = X-Grafana

# List of identity namespaces to add id response headers for, separated by space.
# Available namespaces are user, api-key and service-account.
# The header value will encode the namespace ("user:<id>", "api-key:<id>", "service-account:<id>")
;id_response_header_namespaces = user api-key service-account

#################################### Anonymous Auth ######################
[auth.anonymous]
# enable anonymous access
;enabled = false

# specify organization name that should be used for unauthenticated users
;org_name = Main Org.

# specify role for unauthenticated users
;org_role = Viewer

# mask the Grafana version number for unauthenticated users
;hide_version = false

#################################### GitHub Auth ##########################
[auth.github]
;name = GitHub
;icon = github
;enabled = false
;allow_sign_up = true
;auto_login = false
;client_id = some_id
;client_secret = some_secret
;scopes = user:email,read:org
;auth_url = https://github.com/login/oauth/authorize
;token_url = https://github.com/login/oauth/access_token
;api_url = https://api.github.com/user
;signout_redirect_url =
;allowed_domains =
;team_ids =
;allowed_organizations =
;role_attribute_path =
;role_attribute_strict = false
;allow_assign_grafana_admin = false
;skip_org_role_sync = false

#################################### GitLab Auth #########################
[auth.gitlab]
;name = GitLab
;icon = gitlab
;enabled = false
;allow_sign_up = true
;auto_login = false
;client_id = some_id
;client_secret = some_secret
;scopes = openid email profile
;auth_url = https://gitlab.com/oauth/authorize
;token_url = https://gitlab.com/oauth/token
;api_url = https://gitlab.com/api/v4
;signout_redirect_url =
;allowed_domains =
;allowed_groups =
;role_attribute_path =
;role_attribute_strict = false
;allow_assign_grafana_admin = false
;skip_org_role_sync = false
;tls_skip_verify_insecure = false
;tls_client_cert =
;tls_client_key =
;tls_client_ca =
;use_pkce = true

#################################### Google Auth ##########################
[auth.google]
;name = Google
;icon = google
;enabled = false
;allow_sign_up = true
;auto_login = false
;client_id = some_client_id
;client_secret = some_client_secret
;scopes = openid email profile
;auth_url = https://accounts.google.com/o/oauth2/v2/auth
;token_url = https://oauth2.googleapis.com/token
;api_url = https://openidconnect.googleapis.com/v1/userinfo
;signout_redirect_url =
;allowed_domains =
;validate_hd =
;hosted_domain =
;allowed_groups =
;role_attribute_path =
;role_attribute_strict = false
;allow_assign_grafana_admin = false
;skip_org_role_sync = false
;use_pkce = true

#################################### Grafana.com Auth ####################
[auth.grafana_com]
;name = Grafana.com
;icon = grafana
;enabled = false
;allow_sign_up = true
;auto_login = false
;client_id = some_id
;client_secret = some_secret
;scopes = user:email
;allowed_organizations =
;skip_org_role_sync = false

#################################### Azure AD OAuth #######################
[auth.azuread]
;name = Microsoft
;icon = microsoft
;enabled = false
;allow_sign_up = true
;auto_login = false
;client_id = some_client_id
;client_secret = some_client_secret
;scopes = openid email profile
;auth_url = https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/authorize
;token_url = https://login.microsoftonline.com/<tenant-id>/oauth2/v2.0/token
;signout_redirect_url =
;allowed_domains =
;allowed_groups =
;allowed_organizations =
;role_attribute_strict = false
;allow_assign_grafana_admin = false
;use_pkce = true
# prevent synchronizing users organization roles
;skip_org_role_sync = false

#################################### Okta OAuth #######################
[auth.okta]
;name = Okta
;enabled = false
;allow_sign_up = true
;auto_login = false
;client_id = some_id
;client_secret = some_secret
;scopes = openid profile email groups
;auth_url = https://<tenant-id>.okta.com/oauth2/v1/authorize
;token_url = https://<tenant-id>.okta.com/oauth2/v1/token
;api_url = https://<tenant-id>.okta.com/oauth2/v1/userinfo
;signout_redirect_url =
;allowed_domains =
;allowed_groups =
;role_attribute_path =
;role_attribute_strict = false
;allow_assign_grafana_admin = false
;skip_org_role_sync = false
;use_pkce = true

#################################### Generic OAuth ##########################
[auth.generic_oauth]
;enabled = false
;name = OAuth
;allow_sign_up = true
;auto_login = false
;client_id = some_id
;client_secret = some_secret
;scopes = user:email,read:org
;empty_scopes = false
;email_attribute_name = email:primary
;email_attribute_path =
;login_attribute_path =
;name_attribute_path =
;id_token_attribute_name =
;auth_url = https://foo.bar/login/oauth/authorize
;token_url = https://foo.bar/login/oauth/access_token
;api_url = https://foo.bar/user
;signout_redirect_url =
;teams_url =
;allowed_domains =
;team_ids =
;allowed_organizations =
;role_attribute_path =
;role_attribute_strict = false
;groups_attribute_path =
;team_ids_attribute_path =
;tls_skip_verify_insecure = false
;tls_client_cert =
;tls_client_key =
;tls_client_ca =
;use_pkce = false
;auth_style =
;allow_assign_grafana_admin = false

#################################### Basic Auth ##########################
[auth.basic]
;enabled = true
;password_policy = false

#################################### Auth Proxy ##########################
[auth.proxy]
;enabled = false
;header_name = X-WEBAUTH-USER
;header_property = username
;auto_sign_up = true
;sync_ttl = 60
;whitelist = 192.168.1.1, 192.168.2.1
;headers = Email:X-User-Email, Name:X-User-Name
# Non-ASCII strings in header values are encoded using quoted-printable encoding
;headers_encoded = false
# Read the auth proxy docs for details on what the setting below enables
;enable_login_token = false

#################################### Auth JWT ##########################
[auth.jwt]
;enabled = true
;header_name = X-JWT-Assertion
;email_claim = sub
;username_claim = sub
;jwk_set_url = https://foo.bar/.well-known/jwks.json
;jwk_set_file = /path/to/jwks.json
;cache_ttl = 60m
;expect_claims = {"aud": ["foo", "bar"]}
;key_file = /path/to/key/file
# Use in conjunction with key_file in case the JWT token's header specifies a key ID in "kid" field
;key_id = some-key-id
;role_attribute_path =
;groups_attribute_path =
;role_attribute_strict = false
;auto_sign_up = false
;url_login = false
;allow_assign_grafana_admin = false

#################################### Auth LDAP ##########################
[auth.ldap]
;enabled = false
;config_file = /etc/grafana/ldap.toml
;allow_sign_up = true
# prevent synchronizing ldap users organization roles
;skip_org_role_sync = false

# LDAP background sync (Enterprise only)
# At 1 am every day
;sync_cron = "0 1 * * *"
;active_sync_enabled = true

#################################### AWS ###########################
[aws]
# Enter a comma-separated list of allowed AWS authentication providers.
# Options are: default (AWS SDK Default), keys (Access && secret key), credentials (Credentials field), ec2_iam_role (EC2 IAM Role)
; allowed_auth_providers = default,keys,credentials

# Allow AWS users to assume a role using temporary security credentials.
# If true, assume role will be enabled for all AWS authentication providers that are specified in aws_auth_providers
; assume_role_enabled = true

# Specify max no of pages to be returned by the ListMetricPages API
; list_metrics_page_limit = 500

# Experimental, for use in Grafana Cloud only. Please do not set.
; external_id =

# Sets the expiry duration of an assumed role.
# This setting should be expressed as a duration. Examples: 6h (hours), 10d (days), 2w (weeks), 1M (month).
; session_duration = "15m"

# Set the plugins that will receive AWS settings for each request (via plugin context)
# By default this will include all Grafana Labs owned AWS plugins, or those that make use of AWS settings (ElasticSearch, Prometheus).
; forward_settings_to_plugins = cloudwatch, grafana-athena-datasource, grafana-redshift-datasource, grafana-x-ray-datasource, grafana-timestream-datasource, grafana-iot-sitewise-datasource, grafana-iot-twinmaker-app, grafana-opensearch-datasource, aws-datasource-provisioner, elasticsearch, prometheus

#################################### Azure ###############################
[azure]
# Azure cloud environment where Grafana is hosted
# Possible values are AzureCloud, AzureChinaCloud, AzureUSGovernment and AzureGermanCloud
# Default value is AzureCloud (i.e. public cloud)
;cloud = AzureCloud

# Specifies whether Grafana hosted in Azure service with Managed Identity configured (e.g. Azure Virtual Machines instance)
# If enabled, the managed identity can be used for authentication of Grafana in Azure services
# Disabled by default, needs to be explicitly enabled
;managed_identity_enabled = false

# Client ID to use for user-assigned managed identity
# Should be set for user-assigned identity and should be empty for system-assigned identity
;managed_identity_client_id =

# Specifies whether Azure AD Workload Identity authentication should be enabled in datasources that support it
# For more documentation on Azure AD Workload Identity, review this documentation:
# https://azure.github.io/azure-workload-identity/docs/
# Disabled by default, needs to be explicitly enabled
;workload_identity_enabled = false

# Tenant ID of the Azure AD Workload Identity
# Allows to override default tenant ID of the Azure AD identity associated with the Kubernetes service account
;workload_identity_tenant_id =

# Client ID of the Azure AD Workload Identity
# Allows to override default client ID of the Azure AD identity associated with the Kubernetes service account
;workload_identity_client_id =

# Custom path to token file for the Azure AD Workload Identity
# Allows to set a custom path to the projected service account token file
;workload_identity_token_file =

# Specifies whether user identity authentication (on behalf of currently signed-in user) should be enabled in datasources
# that support it (requires AAD authentication)
# Disabled by default, needs to be explicitly enabled
;user_identity_enabled = false

# Override token URL for Azure Active Directory
# By default is the same as token URL configured for AAD authentication settings
;user_identity_token_url =

# Override ADD application ID which would be used to exchange users token to an access token for the datasource
# By default is the same as used in AAD authentication or can be set to another application (for OBO flow)
;user_identity_client_id =

# Override the AAD application client secret
# By default is the same as used in AAD authentication or can be set to another application (for OBO flow)
;user_identity_client_secret =

# Set the plugins that will receive Azure settings for each request (via plugin context)
# By default this will include all Grafana Labs owned Azure plugins, or those that make use of Azure settings (Azure Monitor, Azure Data Explorer, Prometheus, MSSQL).
;forward_settings_to_plugins = grafana-azure-monitor-datasource, prometheus, grafana-azure-data-explorer-datasource, mssql

#################################### Role-based Access Control ###########
[rbac]
;permission_cache = true

# Reset basic roles permissions on boot
# Warning left to true, basic roles permissions will be reset on every boot
#reset_basic_roles = false

# Validate permissions' action and scope on role creation and update
; permission_validation_enabled = true

#################################### SMTP / Emailing ##########################
[smtp]
;enabled = false
;host = localhost:25
;user =
# If the password contains # or ; you have to wrap it with triple quotes. Ex """#password;"""
;password =
;cert_file =
;key_file =
;skip_verify = false
;from_address = admin@grafana.localhost
;from_name = Grafana
# EHLO identity in SMTP dialog (defaults to instance_name)
;ehlo_identity = dashboard.example.com
# SMTP startTLS policy (defaults to 'OpportunisticStartTLS')
;startTLS_policy = NoStartTLS
# Enable trace propagation in e-mail headers, using the 'traceparent', 'tracestate' and (optionally) 'baggage' fields (defaults to false)
;enable_tracing = false

[smtp.static_headers]
# Include custom static headers in all outgoing emails
;Foo-Header = bar
;Foo = bar

[emails]
;welcome_email_on_sign_up = false
;templates_pattern = emails/*.html, emails/*.txt
;content_types = text/html

#################################### Logging ##########################
[log]
# Either "console", "file", "syslog". Default is console and  file
# Use space to separate multiple modes, e.g. "console file"
;mode = console file

# Either "debug", "info", "warn", "error", "critical", default is "info"
;level = info

# optional settings to set different levels for specific loggers. Ex filters = sqlstore:debug
;filters =

# Set the default error message shown to users. This message is displayed instead of sensitive backend errors which should be obfuscated. Default is the same as the sample value.
;user_facing_default_error = "please inspect Grafana server log for details"

# For "console" mode only
[log.console]
;level =

# log line format, valid options are text, console and json
;format = console

# For "file" mode only
[log.file]
;level =

# log line format, valid options are text, console and json
;format = text

# This enables automated log rotate(switch of following options), default is true
;log_rotate = true

# Max line number of single file, default is 1000000
;max_lines = 1000000

# Max size shift of single file, default is 28 means 1 << 28, 256MB
;max_size_shift = 28

# Segment log daily, default is true
;daily_rotate = true

# Expired days of log file(delete after max days), default is 7
;max_days = 7

[log.syslog]
;level =

# log line format, valid options are text, console and json
;format = text

# Syslog network type and address. This can be udp, tcp, or unix. If left blank, the default unix endpoints will be used.
;network =
;address =

# Syslog facility. user, daemon and local0 through local7 are valid.
;facility =

# Syslog tag. By default, the process' argv[0] is used.
;tag =

[log.frontend]
# Should Faro javascript agent be initialized
;enabled = false

# Custom HTTP endpoint to send events to. Default will log the events to stdout.
;custom_endpoint = /log-grafana-javascript-agent

# Requests per second limit enforced an extended period, for Grafana backend log ingestion endpoint (/log).
;log_endpoint_requests_per_second_limit = 3

# Max requests accepted per short interval of time for Grafana backend log ingestion endpoint (/log).
;log_endpoint_burst_limit = 15

# Should error instrumentation be enabled, only affects Grafana Javascript Agent
;instrumentations_errors_enabled = true

# Should console instrumentation be enabled, only affects Grafana Javascript Agent
;instrumentations_console_enabled = false

# Should webvitals instrumentation be enabled, only affects Grafana Javascript Agent
;instrumentations_webvitals_enabled = false

# Api Key, only applies to Grafana Javascript Agent provider
;api_key = testApiKey

#################################### Usage Quotas ########################
[quota]
; enabled = false

#### set quotas to -1 to make unlimited. ####
# limit number of users per Org.
; org_user = 10

# limit number of dashboards per Org.
; org_dashboard = 100

# limit number of data_sources per Org.
; org_data_source = 10

# limit number of api_keys per Org.
; org_api_key = 10

# limit number of alerts per Org.
;org_alert_rule = 100

# limit number of orgs a user can create.
; user_org = 10

# Global limit of users.
; global_user = -1

# global limit of orgs.
; global_org = -1

# global limit of dashboards
; global_dashboard = -1

# global limit of api_keys
; global_api_key = -1

# global limit on number of logged in users.
; global_session = -1

# global limit of alerts
;global_alert_rule = -1

# global limit of correlations
; global_correlations = -1

# Limit of the number of alert rules per rule group.
# This is not strictly enforced yet, but will be enforced over time.
;alerting_rule_group_rules = 100

#################################### Unified Alerting ####################
[unified_alerting]
#Enable the Unified Alerting sub-system and interface. When enabled we'll migrate all of your alert rules and notification channels to the new system. New alert rules will be created and your notification channels will be converted into an Alertmanager configuration. Previous data is preserved to enable backwards compatibility but new data is removed.```
;enabled = true

# Comma-separated list of organization IDs for which to disable unified alerting. Only supported if unified alerting is enabled.
;disabled_orgs =

# Specify the frequency of polling for admin config changes.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;admin_config_poll_interval = 60s

# Specify the frequency of polling for Alertmanager config changes.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;alertmanager_config_poll_interval = 60s

# The redis server address that should be connected to.
;ha_redis_address =

# The username that should be used to authenticate with the redis server.
;ha_redis_username =

# The password that should be used to authenticate with the redis server.
;ha_redis_password =

# The redis database, by default it's 0.
;ha_redis_db =

# A prefix that is used for every key or channel that is created on the redis server
# as part of HA for alerting.
;ha_redis_prefix =

# The name of the cluster peer that will be used as identifier. If none is
# provided, a random one will be generated.
;ha_redis_peer_name =

# Listen address/hostname and port to receive unified alerting messages for other Grafana instances. The port is used for both TCP and UDP. It is assumed other Grafana instances are also running on the same port. The default value is `0.0.0.0:9094`.
;ha_listen_address = "0.0.0.0:9094"

# Listen address/hostname and port to receive unified alerting messages for other Grafana instances. The port is used for both TCP and UDP. It is assumed other Grafana instances are also running on the same port. The default value is `0.0.0.0:9094`.
;ha_advertise_address = ""

# Comma-separated list of initial instances (in a format of host:port) that will form the HA cluster. Configuring this setting will enable High Availability mode for alerting.
;ha_peers = ""

# Time to wait for an instance to send a notification via the Alertmanager. In HA, each Grafana instance will
# be assigned a position (e.g. 0, 1). We then multiply this position with the timeout to indicate how long should
# each instance wait before sending the notification to take into account replication lag.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;ha_peer_timeout = "15s"

# The label is an optional string to include on each packet and stream.
# It uniquely identifies the cluster and prevents cross-communication
# issues when sending gossip messages in an enviromenet with multiple clusters.
;ha_label =

# The interval between sending gossip messages. By lowering this value (more frequent) gossip messages are propagated
# across cluster more quickly at the expense of increased bandwidth usage.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;ha_gossip_interval = "200ms"

# The interval between gossip full state syncs. Setting this interval lower (more frequent) will increase convergence speeds
# across larger clusters at the expense of increased bandwidth usage.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;ha_push_pull_interval = "60s"

# Enable or disable alerting rule execution. The alerting UI remains visible. This option has a legacy version in the `[alerting]` section that takes precedence.
;execute_alerts = true

# Alert evaluation timeout when fetching data from the datasource. This option has a legacy version in the `[alerting]` section that takes precedence.
# The timeout string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;evaluation_timeout = 30s

# Number of times we'll attempt to evaluate an alert rule before giving up on that evaluation. The default value is 1.
;max_attempts = 1

# Minimum interval to enforce between rule evaluations. Rules will be adjusted if they are less than this value  or if they are not multiple of the scheduler interval (10s). Higher values can help with resource management as we'll schedule fewer evaluations over time. This option has a legacy version in the `[alerting]` section that takes precedence.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;min_interval = 10s

# This is an experimental option to add parallelization to saving alert states in the database.
# It configures the maximum number of concurrent queries per rule evaluated. The default value is 1
# (concurrent queries per rule disabled).
;max_state_save_concurrency = 1

# If the feature flag 'alertingSaveStatePeriodic' is enabled, this is the interval that is used to persist the alerting instances to the database.
# The interval string is a possibly signed sequence of decimal numbers, followed by a unit suffix (ms, s, m, h, d), e.g. 30s or 1m.
;state_periodic_save_interval = 5m

# Disables the smoothing of alert evaluations across their evaluation window.
# Rules will evaluate in sync.
;disable_jitter = false

[unified_alerting.reserved_labels]
# Comma-separated list of reserved labels added by the Grafana Alerting engine that should be disabled.
# For example: `disabled_labels=grafana_folder`
;disabled_labels =

[unified_alerting.state_history]
# Enable the state history functionality in Unified Alerting. The previous states of alert rules will be visible in panels and in the UI.
; enabled = true

# Select which pluggable state history backend to use. Either "annotations", "loki", or "multiple"
# "loki" writes state history to an external Loki instance. "multiple" allows history to be written to multiple backends at once.
# Defaults to "annotations".
; backend = "multiple"

# For "multiple" only.
# Indicates the main backend used to serve state history queries.
# Either "annotations" or "loki"
; primary = "loki"

# For "multiple" only.
# Comma-separated list of additional backends to write state history data to.
; secondaries = "annotations"

# For "loki" only.
# URL of the external Loki instance.
# Either "loki_remote_url", or both of "loki_remote_read_url" and "loki_remote_write_url" is required for the "loki" backend.
; loki_remote_url = "http://loki:3100"

# For "loki" only.
# URL of the external Loki's read path. To be used in configurations where Loki has separated read and write URLs.
# Either "loki_remote_url", or both of "loki_remote_read_url" and "loki_remote_write_url" is required for the "loki" backend.
; loki_remote_read_url = "http://loki-querier:3100"

# For "loki" only.
# URL of the external Loki's write path. To be used in configurations where Loki has separated read and write URLs.
# Either "loki_remote_url", or both of "loki_remote_read_url" and "loki_remote_write_url" is required for the "loki" backend.
; loki_remote_write_url = "http://loki-distributor:3100"

# For "loki" only.
# Optional tenant ID to attach to requests sent to Loki.
; loki_tenant_id = 123

# For "loki" only.
# Optional username for basic authentication on requests sent to Loki. Can be left blank to disable basic auth.
; loki_basic_auth_username = "myuser"

# For "loki" only.
# Optional password for basic authentication on requests sent to Loki. Can be left blank.
; loki_basic_auth_password = "mypass"

[unified_alerting.state_history.external_labels]
# Optional extra labels to attach to outbound state history records or log streams.
# Any number of label key-value-pairs can be provided.
; mylabelkey = mylabelvalue

[unified_alerting.state_history.annotations]
# This section controls retention of annotations automatically created while evaluating alert rules
# when alerting state history backend is configured to be annotations (a setting [unified_alerting.state_history].backend

# Configures for how long alert annotations are stored. Default is 0, which keeps them forever.
# This setting should be expressed as an duration. Ex 6h (hours), 10d (days), 2w (weeks), 1M (month).
max_age =

# Configures max number of alert annotations that Grafana stores. Default value is 0, which keeps all alert annotations.
max_annotations_to_keep =

[unified_alerting.upgrade]
# If set to true when upgrading from legacy alerting to Unified Alerting, grafana will first delete all existing
# Unified Alerting resources, thus re-upgrading all organizations from scratch. If false or unset, organizations that
# have previously upgraded will not lose their existing Unified Alerting data when switching between legacy and
# Unified Alerting. Should be kept false when not needed as it may cause unintended data-loss if left enabled.
;clean_upgrade = false

#################################### Alerting ############################
[alerting]
# Disable legacy alerting engine & UI features
;enabled = false

# Makes it possible to turn off alert execution but alerting UI is visible
;execute_alerts = true

# Default setting for new alert rules. Defaults to categorize error and timeouts as alerting. (alerting, keep_state)
;error_or_timeout = alerting

# Default setting for how Grafana handles nodata or null values in alerting. (alerting, no_data, keep_state, ok)
;nodata_or_nullvalues = no_data

# Alert notifications can include images, but rendering many images at the same time can overload the server
# This limit will protect the server from render overloading and make sure notifications are sent out quickly
;concurrent_render_limit = 5

# Default setting for alert calculation timeout. Default value is 30
;evaluation_timeout_seconds = 30

# Default setting for alert notification timeout. Default value is 30
;notification_timeout_seconds = 30

# Default setting for max attempts to sending alert notifications. Default value is 3
;max_attempts = 3

# Makes it possible to enforce a minimal interval between evaluations, to reduce load on the backend
;min_interval_seconds = 1

# Configures for how long alert annotations are stored. Default is 0, which keeps them forever.
# This setting should be expressed as a duration. Examples: 6h (hours), 10d (days), 2w (weeks), 1M (month).
# Deprecated, use [annotations.alerting].max_age instead
;max_annotation_age =

# Configures max number of alert annotations that Grafana stores. Default value is 0, which keeps all alert annotations.
# Deprecated, use [annotations.alerting].max_annotations_to_keep instead
;max_annotations_to_keep =

#################################### Annotations #########################
[annotations]
# Configures the batch size for the annotation clean-up job. This setting is used for dashboard, API, and alert annotations.
;cleanupjob_batchsize = 100

# Enforces the maximum allowed length of the tags for any newly introduced annotations. It can be between 500 and 4096 inclusive (which is the respective's column length). Default value is 500.
# Setting it to a higher value would impact performance therefore is not recommended.
;tags_length = 500

[annotations.dashboard]
# Dashboard annotations means that annotations are associated with the dashboard they are created on.

# Configures how long dashboard annotations are stored. Default is 0, which keeps them forever.
# This setting should be expressed as a duration. Examples: 6h (hours), 10d (days), 2w (weeks), 1M (month).
;max_age =

# Configures max number of dashboard annotations that Grafana stores. Default value is 0, which keeps all dashboard annotations.
;max_annotations_to_keep =

[annotations.api]
# API annotations means that the annotations have been created using the API without any
# association with a dashboard.

# Configures how long Grafana stores API annotations. Default is 0, which keeps them forever.
# This setting should be expressed as a duration. Examples: 6h (hours), 10d (days), 2w (weeks), 1M (month).
;max_age =

# Configures max number of API annotations that Grafana keeps. Default value is 0, which keeps all API annotations.
;max_annotations_to_keep =

#################################### Explore #############################
[explore]
# Enable the Explore section
;enabled = true

#################################### Help #############################
[help]
# Enable the Help section
;enabled = true

#################################### Profile #############################
[profile]
# Enable the Profile section
;enabled = true

#################################### News #############################
[news]
# Enable the news feed section
; news_feed_enabled = true

#################################### Query #############################
[query]
# Set the number of data source queries that can be executed concurrently in mixed queries. Default is the number of CPUs.
;concurrent_query_limit =

#################################### Query History #############################
[query_history]
# Enable the Query history
;enabled = true

#################################### Internal Grafana Metrics ##########################
# Metrics available at HTTP URL /metrics and /metrics/plugins/:pluginId
[metrics]
# Disable / Enable internal metrics
;enabled           = true
# Graphite Publish interval
;interval_seconds  = 10
# Disable total stats (stat_totals_*) metrics to be generated
;disable_total_stats = false
# The interval at which the total stats collector will update the stats. Default is 1800 seconds.
;total_stats_collector_interval_seconds = 1800

#If both are set, basic auth will be required for the metrics endpoints.
; basic_auth_username =
; basic_auth_password =

# Metrics environment info adds dimensions to the `grafana_environment_info` metric, which
# can expose more information about the Grafana instance.
[metrics.environment_info]
#exampleLabel1 = exampleValue1
#exampleLabel2 = exampleValue2

# Send internal metrics to Graphite
[metrics.graphite]
# Enable by setting the address setting (ex localhost:2003)
;address =
;prefix = prod.grafana.%(instance_name)s.

#################################### Grafana.com integration  ##########################
# Url used to import dashboards directly from Grafana.com
[grafana_com]
;url = https://grafana.com
;api_url = https://grafana.com/api

#################################### Distributed tracing ############
# Opentracing is deprecated use opentelemetry instead
[tracing.jaeger]
# Enable by setting the address sending traces to jaeger (ex localhost:6831)
;address = localhost:6831
# Tag that will always be included in when creating new spans. ex (tag1:value1,tag2:value2)
;always_included_tag = tag1:value1
# Type specifies the type of the sampler: const, probabilistic, rateLimiting, or remote
;sampler_type = const
# jaeger samplerconfig param
# for "const" sampler, 0 or 1 for always false/true respectively
# for "probabilistic" sampler, a probability between 0 and 1
# for "rateLimiting" sampler, the number of spans per second
# for "remote" sampler, param is the same as for "probabilistic"
# and indicates the initial sampling rate before the actual one
# is received from the mothership
;sampler_param = 1
# sampling_server_url is the URL of a sampling manager providing a sampling strategy.
;sampling_server_url =
# Whether or not to use Zipkin propagation (x-b3- HTTP headers).
;zipkin_propagation = false
# Setting this to true disables shared RPC spans.
# Not disabling is the most common setting when using Zipkin elsewhere in your infrastructure.
;disable_shared_zipkin_spans = false

[tracing.opentelemetry]
# attributes that will always be included in when creating new spans. ex (key1:value1,key2:value2)
;custom_attributes = key1:value1,key2:value2
# Type specifies the type of the sampler: const, probabilistic, rateLimiting, or remote
; sampler_type = remote
# Sampler configuration parameter
# for "const" sampler, 0 or 1 for always false/true respectively
# for "probabilistic" sampler, a probability between 0.0 and 1.0
# for "rateLimiting" sampler, the number of spans per second
# for "remote" sampler, param is the same as for "probabilistic"
#   and indicates the initial sampling rate before the actual one
#   is received from the sampling server (set at sampling_server_url)
; sampler_param = 0.5
# specifies the URL of the sampling server when sampler_type is remote
; sampling_server_url = http://localhost:5778/sampling

[tracing.opentelemetry.jaeger]
# jaeger destination (ex http://localhost:14268/api/traces)
; address = http://localhost:14268/api/traces
# Propagation specifies the text map propagation format: w3c, jaeger
; propagation = jaeger

# This is a configuration for OTLP exporter with GRPC protocol
[tracing.opentelemetry.otlp]
# otlp destination (ex localhost:4317)
; address = localhost:4317
# Propagation specifies the text map propagation format: w3c, jaeger
; propagation = w3c

#################################### External image storage ##########################
[external_image_storage]
# Used for uploading images to public servers so they can be included in slack/email messages.
# you can choose between (s3, webdav, gcs, azure_blob, local)
;provider =

[external_image_storage.s3]
;endpoint =
;path_style_access =
;bucket =
;region =
;path =
;access_key =
;secret_key =

[external_image_storage.webdav]
;url =
;public_url =
;username =
;password =

[external_image_storage.gcs]
;key_file =
;bucket =
;path =

[external_image_storage.azure_blob]
;account_name =
;account_key =
;container_name =
;sas_token_expiration_days =

[external_image_storage.local]
# does not require any configuration

[rendering]
# Options to configure a remote HTTP image rendering service, e.g. using https://github.com/grafana/grafana-image-renderer.
# URL to a remote HTTP image renderer service, e.g. http://localhost:8081/render, will enable Grafana to render panels and dashboards to PNG-images using HTTP requests to an external service.
;server_url =
# If the remote HTTP image renderer service runs on a different server than the Grafana server you may have to configure this to a URL where Grafana is reachable, e.g. http://grafana.domain/.
;callback_url =
# An auth token that will be sent to and verified by the renderer. The renderer will deny any request without an auth token matching the one configured on the renderer side.
;renderer_token = -
# Concurrent render request limit affects when the /render HTTP endpoint is used. Rendering many images at the same time can overload the server,
# which this setting can help protect against by only allowing a certain amount of concurrent requests.
;concurrent_render_request_limit = 30
# Determines the lifetime of the render key used by the image renderer to access and render Grafana.
# This setting should be expressed as a duration. Examples: 10s (seconds), 5m (minutes), 2h (hours).
# Default is 5m. This should be more than enough for most deployments.
# Change the value only if image rendering is failing and you see `Failed to get the render key from cache` in Grafana logs.
;render_key_lifetime = 5m

[panels]
# If set to true Grafana will allow script tags in text panels. Not recommended as it enable XSS vulnerabilities.
;disable_sanitize_html = false

[plugins]
;enable_alpha = false
;app_tls_skip_verify_insecure = false
# Enter a comma-separated list of plugin identifiers to identify plugins to load even if they are unsigned. Plugins with modified signatures are never loaded.
;allow_loading_unsigned_plugins =
# Enable or disable installing / uninstalling / updating plugins directly from within Grafana.
;plugin_admin_enabled = false
;plugin_admin_external_manage_enabled = false
;plugin_catalog_url = https://grafana.com/grafana/plugins/
# Enter a comma-separated list of plugin identifiers to hide in the plugin catalog.
;plugin_catalog_hidden_plugins =
# Log all backend requests for core and external plugins.
;log_backend_requests = false
# Disable download of the public key for verifying plugin signature.
; public_key_retrieval_disabled = false
# Force download of the public key for verifying plugin signature on startup. If disabled, the public key will be retrieved every 10 days.
# Requires public_key_retrieval_disabled to be false to have any effect.
; public_key_retrieval_on_startup = false
# Enter a comma-separated list of plugin identifiers to avoid loading (including core plugins). These plugins will be hidden in the catalog.
; disable_plugins =

#################################### Grafana Live ##########################################
[live]
# max_connections to Grafana Live WebSocket endpoint per Grafana server instance. See Grafana Live docs
# if you are planning to make it higher than default 100 since this can require some OS and infrastructure
# tuning. 0 disables Live, -1 means unlimited connections.
;max_connections = 100

# allowed_origins is a comma-separated list of origins that can establish connection with Grafana Live.
# If not set then origin will be matched over root_url. Supports wildcard symbol "*".
;allowed_origins =

# engine defines an HA (high availability) engine to use for Grafana Live. By default no engine used - in
# this case Live features work only on a single Grafana server. Available options: "redis".
# Setting ha_engine is an EXPERIMENTAL feature.
;ha_engine =

# ha_engine_address sets a connection address for Live HA engine. Depending on engine type address format can differ.
# For now we only support Redis connection address in "host:port" format.
# This option is EXPERIMENTAL.
;ha_engine_address = "127.0.0.1:6379"

# ha_engine_password allows setting an optional password to authenticate with the engine
;ha_engine_password = ""

#################################### Grafana Image Renderer Plugin ##########################
[plugin.grafana-image-renderer]
# Instruct headless browser instance to use a default timezone when not provided by Grafana, e.g. when rendering panel image of alert.
# See ICU’s metaZones.txt (https://cs.chromium.org/chromium/src/third_party/icu/source/data/misc/metaZones.txt) for a list of supported
# timezone IDs. Fallbacks to TZ environment variable if not set.
;rendering_timezone =

# Instruct headless browser instance to use a default language when not provided by Grafana, e.g. when rendering panel image of alert.
# Please refer to the HTTP header Accept-Language to understand how to format this value, e.g. 'fr-CH, fr;q=0.9, en;q=0.8, de;q=0.7, *;q=0.5'.
;rendering_language =

# Instruct headless browser instance to use a default device scale factor when not provided by Grafana, e.g. when rendering panel image of alert.
# Default is 1. Using a higher value will produce more detailed images (higher DPI), but will require more disk space to store an image.
;rendering_viewport_device_scale_factor =

# Instruct headless browser instance whether to ignore HTTPS errors during navigation. Per default HTTPS errors are not ignored. Due to
# the security risk it's not recommended to ignore HTTPS errors.
;rendering_ignore_https_errors =

# Instruct headless browser instance whether to capture and log verbose information when rendering an image. Default is false and will
# only capture and log error messages. When enabled, debug messages are captured and logged as well.
# For the verbose information to be included in the Grafana server log you have to adjust the rendering log level to debug, configure
# [log].filter = rendering:debug.
;rendering_verbose_logging =

# Instruct headless browser instance whether to output its debug and error messages into running process of remote rendering service.
# Default is false. This can be useful to enable (true) when troubleshooting.
;rendering_dumpio =

# Additional arguments to pass to the headless browser instance. Default is --no-sandbox. The list of Chromium flags can be found
# here (https://peter.sh/experiments/chromium-command-line-switches/). Multiple arguments is separated with comma-character.
;rendering_args =

# You can configure the plugin to use a different browser binary instead of the pre-packaged version of Chromium.
# Please note that this is not recommended, since you may encounter problems if the installed version of Chrome/Chromium is not
# compatible with the plugin.
;rendering_chrome_bin =

# Instruct how headless browser instances are created. Default is 'default' and will create a new browser instance on each request.
# Mode 'clustered' will make sure that only a maximum of browsers/incognito pages can execute concurrently.
# Mode 'reusable' will have one browser instance and will create a new incognito page on each request.
;rendering_mode =

# When rendering_mode = clustered, you can instruct how many browsers or incognito pages can execute concurrently. Default is 'browser'
# and will cluster using browser instances.
# Mode 'context' will cluster using incognito pages.
;rendering_clustering_mode =
# When rendering_mode = clustered, you can define the maximum number of browser instances/incognito pages that can execute concurrently. Default is '5'.
;rendering_clustering_max_concurrency =
# When rendering_mode = clustered, you can specify the duration a rendering request can take before it will time out. Default is `30` seconds.
;rendering_clustering_timeout =

# Limit the maximum viewport width, height and device scale factor that can be requested.
;rendering_viewport_max_width =
;rendering_viewport_max_height =
;rendering_viewport_max_device_scale_factor =

# Change the listening host and port of the gRPC server. Default host is 127.0.0.1 and default port is 0 and will automatically assign
# a port not in use.
;grpc_host =
;grpc_port =

[support_bundles]
# Enable support bundle creation (default: true)
#enabled = true
# Only server admins can generate and view support bundles (default: true)
#server_admin_only = true
# If set, bundles will be encrypted with the provided public keys separated by whitespace
#public_keys = ""

[enterprise]
# Path to a valid Grafana Enterprise license.jwt file
;license_path =

[feature_toggles]
# there are currently two ways to enable feature toggles in the `grafana.ini`.
# you can either pass an array of feature you want to enable to the `enable` field or
# configure each toggle by setting the name of the toggle to true/false. Toggles set to true/false
# will take presidence over toggles in the `enable` list.

;enable = feature1,feature2

;feature1 = true
;feature2 = false

[date_formats]
# For information on what formatting patterns that are supported https://momentjs.com/docs/#/displaying/

# Default system date format used in time range picker and other places where full time is displayed
;full_date = YYYY-MM-DD HH:mm:ss

# Used by graph and other places where we only show small intervals
;interval_second = HH:mm:ss
;interval_minute = HH:mm
;interval_hour = MM/DD HH:mm
;interval_day = MM/DD
;interval_month = YYYY-MM
;interval_year = YYYY

# Experimental feature
;use_browser_locale = false

# Default timezone for user preferences. Options are 'browser' for the browser local timezone or a timezone name from IANA Time Zone database, e.g. 'UTC' or 'Europe/Amsterdam' etc.
;default_timezone = browser

[expressions]
# Enable or disable the expressions functionality.
;enabled = true

[geomap]
# Set the JSON configuration for the default basemap
;default_baselayer_config = `{
;  "type": "xyz",
;  "config": {
;    "attribution": "Open street map",
;    "url": "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
;  }
;}`

# Enable or disable loading other base map layers
;enable_custom_baselayers = true

# Move an app plugin referenced by its id (including all its pages) to a specific navigation section
[navigation.app_sections]
# The following will move an app plugin with the id of `my-app-id` under the `cfg` section
# my-app-id = cfg

# Move a specific app plugin page (referenced by its `path` field) to a specific navigation section
[navigation.app_standalone_pages]
# The following will move the page with the path "/a/my-app-id/my-page" from `my-app-id` to the `cfg` section
# /a/my-app-id/my-page = cfg

#################################### Secure Socks5 Datasource Proxy #####################################
[secure_socks_datasource_proxy]
; enabled = false
; root_ca_cert =
; client_key =
; client_cert =
; server_name =
# The address of the socks5 proxy datasources should connect to
; proxy_address =
; show_ui = true
; allow_insecure = false

################################## Feature Management ##############################################
[feature_management]
# Options to configure the experimental Feature Toggle Admin Page feature, which is behind the `featureToggleAdminPage` feature toggle. Use at your own risk.
# Allow editing of feature toggles in the feature management page
;allow_editing = false
# Allow customization of URL for the controller that manages feature toggles
;update_webhook =
# Allow configuring an auth token for feature management update requests
;update_webhook_token =
# Hide specific feature toggles from the feature management page
;hidden_toggles =
# Disable updating specific feature toggles in the feature management page
;read_only_toggles =

#################################### Public Dashboards #####################################
[public_dashboards]
# Set to false to disable public dashboards
;enabled = true

EOF

# write docker compose config file

tee $HOME/.local/share/tig-stack/docker-compose.yaml 2>&1 > /dev/null <<EOF
version: "3.8"
services:
  influxdb:
    image: influxdb:2.7.5
    container_name: influxdb
    environment:
      - DOCKER_INFLUXDB_INIT_MODE=setup
      - DOCKER_INFLUXDB_INIT_USERNAME=$INFLUXDB_GRAFANA_USER
      - DOCKER_INFLUXDB_INIT_PASSWORD=$INFLUXDB_GRAFANA_PASSWORD
      - DOCKER_INFLUXDB_INIT_ORG=safe-org
      - DOCKER_INFLUXDB_INIT_BUCKET=telegraf
      - DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$INFLUXDB_TOKEN
    volumes:
      # Make sure you create these local directories
      - $HOME/.local/share/tig-stack/influxdb/data:/var/lib/influxdb2
      - $HOME/.local/share/tig-stack/influxdb/config:/etc/influxdb2
    ports:
      - 8086:8086
    restart: unless-stopped
    networks:
      - tig_network
    healthcheck:
      test: "curl -f http://localhost:8086/ping"
      interval: 5s
      timeout: 10s
      retries: 5

  grafana:
    image: grafana/grafana-enterprise
    container_name: grafana
    user: "1000:1000"
    ports:
      - 3000:3000
    volumes:
      # Make sure you create these local directories
      - $HOME/.local/share/tig-stack/grafana/data:/var/lib/grafana
      - $HOME/.local/share/tig-stack/grafana/config:/etc/grafana
      - $HOME/.local/share/tig-stack/grafana/log:/var/log/grafana
    restart: unless-stopped
    environment:
       - GF_PATHS_CONFIG=/etc/grafana/custom.ini

    networks:
      - tig_network

networks:
  tig_network:
    driver: bridge
EOF


docker compose --project-directory $HOME/.local/share/tig-stack/ up


############################################################################################################################################## Install Docker Engine
elif [[ "$SELECTION" == "3" ]]; then

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

#test install with
#sudo docker run hello-world


#set up docker user so dont have to run all comands as roor or with sudo
sudo groupadd docker
sleep 1
sudo usermod -aG docker $USER
sleep 1
newgrp docker
sleep 1
# test without sudo

# to test install you can run 
#                                docker run hello-world

############################################################################################################################################## Exit
elif [[ "$SELECTION" == "4" ]]; then

exit 0

############################################################################################################################################### Stop & Uninstall TIG Stack
elif [[ "$SELECTION" == "5" ]]; then

echo " stoping docker containers"
docker compose --project-directory $HOME/.local/share/tig-stack/telegraf/ down
echo ""
sudo rm -rf $HOME/.local/share/tig-stack/

fi
