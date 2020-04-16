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

Check slots and print to STDOUT:
```
$ ./esselunga.pl -u username -p password
```
Check slots and send email notifications (SMTP variables in the code):
```
$ ./esselunga.pl -u username -p password -e email@test.com,email1@test.com,email2.test.com
```
Check slots, send email and Book any available slot. If anyone already booked, book only if more recent:
```
$ ./esselunga.pl -u username -p password -e email@test.com,email1@test.com,email2.test.com -b
```
Check slots and send email notifications (SMTP variables and Booking as ENV):
```
$ SMTP_SERVER=smtp.test.com SMTP_USER=test SMTP_PASS=pass SMTP_PORT=587 SMTP_SERVER_SSL=1 EMAIL_FROM=info@test.it ./esselunga.pl -u username -p password -e email@test.com,email1@test.com,email2.test.com
$ USERNAME=username PASSWORD=password EMAIL=email@test.com SMTP_SERVER=smtp.test.com SMTP_USER=test SMTP_PASS=pass SMTP_PORT=587 SMTP_SERVER_SSL=1 EMAIL_FROM=info@test.it BOOKING=1 ./esselunga.pl
```
### Podman and Buildah

```
$ buildah bud -t esselunga .
$ podman run -e USERNAME=username PASSWORD=password EMAIL=email@test.com SMTP_SERVER=smtp.test.com SMTP_USER=test SMTP_PASS=pass SMTP_PORT=587 SMTP_SERVER_SSL=1 EMAIL_FROM=info@test.it BOOKING=0 -ti localhost/esselunga
```

### Kubernetes

#### CronJob

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: esselunga-slots-hourly
spec:
  schedule: "@hourly"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: smartqueue
            image: quay.io/bluesman/smartqueue:latest
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
                value: '587'
              - name: SMTP_SERVER_SSL
                value: '1'
              - name: EMAIL_FROM
                value: info@test.com
              - name: BOOKING
                value: '0'
          restartPolicy: Never
```

```
$ kubectl apply -f cronjob.yaml
```

### CronJob using Secret and PersistentVolumeClaim

For faster checks storing cookies and DB on a PV:

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: smartqueue-slots
spec:
  schedule: '*/5 * * * *'
  concurrencyPolicy: Forbid
  startingDeadlineSeconds: 10
  jobTemplate:
    spec:
      template:
        spec:
          volumes:
            - name: datapath
              persistentVolumeClaim:
                claimName: smartqueue-pvc
          containers:
          - name: smartqueue
            image: quay.io/bluesman/smartqueue:latest
            volumeMounts:
              - name: datapath
                mountPath: /data
            env:
              - name: DATAPATH
                value: /data
              - name: USERNAME
                value: 'user'
              - name: PASSWORD
                valueFrom:
                  secretKeyRef:
                    name: smartqueue-secret
                    key: website-password
              - name: EMAIL
                value: 'test@test.com'
              - name: SMTP_SERVER
                value: 'mail.test.com'
              - name: SMTP_SERVER_SSL
                value: '1'
              - name: SMTP_USER
                value: 'user'
              - name: SMTP_PASS
                valueFrom:
                  secretKeyRef:
                    name: smartqueue-secret
                    key: smtp-password
              - name: SMTP_PORT
                value: '587'
              - name: EMAIL_FROM
                value: 'send@test.com'
          restartPolicy: Never

```

### OpenShift

```
$ oc new-app https://github.com/blues-man/smartqueue.git --env USERNAME=user --env PASSWORD=pass --env SMTP_SERVER=smtp.test.com --env SMTP_USER=test --env SMTP_PASS=pass --env SMTP_PORT=587 --env SMTP_SERVER_SSL=1 --env EMAIL_FROM=info@test.it --strategy=docker
```

#### OpenShift Template

Available for your project:
```
$ oc create -f smartqueue-template.yaml
```

Available globally

```
$ oc create -f smartqueue-template.yaml -n openshift
```

Use it from command line:

```
$ oc process smartqueue-template -n openshift -p WEBSITE_USERNAME=user -p WEBSITE_PASSWORD=pass -P CRONJOB_SCHEDULE="@hourly" -p SMTP_SERVER=smtp.test.com -p SMTP_USER=test -p SMTP_PASS=pass -p SMTP_PORT=587 -p SMTP_SERVER_SSL=1 -p EMAIL_FROM=info@test.it | oc create -f -
```
#### OpenShift Template Persistent

Save cookies and DB for faster checks, creates a PVC with parametrized size

```
$ oc create -f smartqueue-template-persistent.yaml
```

Use it from Developer Catalog:

![Template search](/images/template1.png)

![Template parameters](/images/template2.png)

See it running!

![OCP Screenshot](/images/template3.png)
