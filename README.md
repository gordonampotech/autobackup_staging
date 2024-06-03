# Home Assistant Add-on: Autobackup-Staging

Backup Automation and Restoration.

![The Autobackup Home Assistant Add-on](images/screenshot.png)

## About

Autobackup is an addon for your Home Assistant device which allows you to automatically
backup your Home Assitant once you install and start the add-on. The backup is run automatically
every 10 days, ensuring that your settings, integrations and data are kept safe with us.

Autobackup also provides a way for you to restore your existing and previous Home Assitant backups
that are kept safe with us, which can be accessed using the web ui in the addon page.

## To Developers

To update the version of the addon

Change the version in ./autobackup/config.yaml, e.g. version: "1.0.2" -> version: "1.2.0"

After that, build the new docker image and push to the docker registry
```
docker build -t ghcr.io/gordonampotech/autobackup-staging:<version_number> --platform linux/aarch64 .
docker push ghcr.io/gordonampotech/autobackup-staging:<version_number>
```

The update will show up automatically in home assistant, but will take a bit of time even after manually clicking check for update.

## Support

Require support to setup the add-on or have any questions?

You have several options to get them answered:

- Phone: +65 6610 6244
- Email: support@ampotech.com

You could also [open an issue here][issue] GitHub.

## Author

The original setup of this repository is by [Gordon Lim][gordonampotech].