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
$ ./esselunga.pl -u username -p password -e email@test.com,email1@test.com,email2.test.com
$ SMTP_SERVER=smtp.test.com SMTP_USER=test SMTP_PASS=pass SMTP_PORT=587 SMTP_SERVER_SSL=1 EMAIL_FROM=info@test.it ./esselunga.pl -u username -p password -e email@test.com,email1@test.com,email2.test.com
$ USERNAME=username PASSWORD=password EMAIL=email@test.com SMTP_SERVER=smtp.test.com SMTP_USER=test SMTP_PASS=pass SMTP_PORT=587 SMTP_SERVER_SSL=1 EMAIL_FROM=info@test.it ./esselunga.pl
```

### OpenShift

```
$ oc new-app https://github.com/blues-man/smartqueue.git --env USERNAME=user --env PASSWORD=pass --env SMTP_SERVER=smtp.test.com --env SMTP_USER=test --envSMTP_PASS=pass --env SMTP_PORT=587 --env SMTP_SERVER_SSL=1 --env EMAIL_FROM=info@test.it
```

### Kubernetes

####CronJob

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: esselunga-slots-hourly
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: smartqueue
            image: smartqueue:latest
            env:
            - name: USERNAME
              value: user
            - name: PASSWORD
              value: pass
            - name: EMAIL
              value: test@test.com
            - name: SMTP_SERVER
              value: smtp.test.com
            - name: SMTP_USER
              value: test
            - name: SMTP_PASS
              value: pass
            - name: SMTP_PORT
              value: 587
            - name: EMAIL_FROM:
              value: info@test.com
          restartPolicy: Never
```
