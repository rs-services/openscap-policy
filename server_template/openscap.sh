#! /usr/bin/sudo /bin/bash
# ---
# RightScript Name: OpenScap Install
# Description: Installs OpenScap
# Inputs: {}
# ...
#
set -e
set +x
if [ ! -e /opt/rebooted ]; then
  yum update -y --quiet
  yum groupinstall -y "Minimal Install" "Development Tools" --quiet
  yum install wget vim -y
  wget http://copr.fedoraproject.org/coprs/openscapmaint/openscap-latest/repo/epel-7/openscapmaint-openscap-latest-epel-7.repo -O /etc/yum.repos.d/openscapmaint-openscap-latest-epel-7.repo
  yum install vim openscap* scap-security-guide python-pip python-devel git epel-release -y
  pip install flask Twisted supervisor
  touch /opt/rebooted
  reboot
fi

sudo service oscapd restart

cd /opt
git clone git://github.com/mvazquezc/oscap-daemon-api.git
cd oscap-daemon-api
sed -i -e 's/app.run()/app.run(host="0.0.0.0",port=80)/' api.py
cat <<EOF> /etc/supervisord.conf
[unix_http_server]
file=/tmp/supervisor.sock   ; the path to the socket file

[inet_http_server]         ; inet (TCP) server disabled by default
port=*:9001        ; ip_address:port specifier, *:port for all iface

[supervisord]
logfile=/tmp/supervisord.log ; main log file; default $CWD/supervisord.log
logfile_maxbytes=50MB        ; max main logfile bytes b4 rotation; default 50MB
logfile_backups=10           ; # of main logfile backups; 0 means none, default 10
loglevel=info                ; log level; default info; others: debug,warn,trace
pidfile=/tmp/supervisord.pid ; supervisord pidfile; default supervisord.pid
nodaemon=false               ; start in foreground if true; default false
minfds=1024                  ; min. avail startup file descriptors; default 1024
minprocs=200                 ; min. avail process descriptors;default 200

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock ; use a unix:// URL  for a unix socket
history_file=~/.sc_history  ; use readline history if available

[program:python]
command=/bin/python api.py
process_name=%(program_name)s
numprocs=1 
directory=/opt/oscap-daemon-api
autostart=true
redirect_stderr=true
stdout_logfile=/tmp/oscap-daemon-api.log        ; stdout log path, NONE for none; default AUTO
stdout_logfile_maxbytes=1MB   ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=10     ; # of stdout logfile backups (0 means none, default 10)
stdout_capture_maxbytes=1MB   ; number of bytes in 'capturemode' (default 0)
stdout_events_enabled=false   ; emit events on stdout writes (default false)
EOF

/bin/supervisord &

oscap xccdf eval --fetch-remote-resources --profile standard --results-arf arf.xml --report report.html /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml &
cat <<EOF> /tmp/newtask.json
{
    "taskTitle":"Standard Test",
    "taskTarget":"localhost",
    "taskSSG":"/usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml",
    "taskTailoring":"",
    "taskProfileId":"xccdf_org.ssgproject.content_profile_standard",
    "taskOnlineRemediation":"-0",
    "taskScheduleNotBefore":"",
    "taskScheduleRepeatAfter":""
}
EOF