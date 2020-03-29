# smartqueue
Esselungaacasa.it smart free delivery slots alerting system


## Dependency

### Fedora/CentOS

```
# dnf install -y perl-libwww-perl perl-LWP-Protocol-https perl-Authen-SASL perl-DBD-SQLite perl-DBD-SQLite perl-MIME-Lite perl-JSON-MaybeXS
```

### Debian/Ubuntu

```
# apt-get install -y libauthen-sasl-perl libmime-lite-perl libdbd-sqlite3-perl libwww-perl libjson-maybexs-perl
```

## Timer & Systemd

```
# cp esselunga@.service esselunga-hourly.timer /usr/lib/systemd/system
# systemctl enable esselunga@.service
# systemctl enable esselunga-hourly.timer
# systemctl start esselunga-hourly.timer
# systemctl list-timers
```
## Usage

```
$ ./esselunga.pl -u username -p password
$ ./esselunga.pl -u username -p password -e email@test.com,email1@test.com,email2.test.com -c milano
$ USERNAME=username PASSWORD=password EMAIL=email@test.com ./esselunga.pl
```

### OpenShift

```
$ oc new-app https://github.com/blues-man/smartqueue.git --env USERNAME=user --env PASSWORD=pass --env EMAIL=email@test.com 
```

