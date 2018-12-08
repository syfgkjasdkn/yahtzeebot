[![Build Status](https://semaphoreci.com/api/v1/syfgkjasdkn/yahtzeebot/branches/master/badge.svg)](https://semaphoreci.com/syfgkjasdkn/yahtzeebot)

---

### Build

`MIX_ENV=prod mix do compile, release --env=prod --verbose`

This would produce an archive with all the necessary dependencies. Note that for compiling `tdlib` and `libsecp256k1` you need to install the required libs. Also note that `tdlib` takes about 10 minutes and ~7GB of RAM to compile on my laptop. These libraries need to be compiled on the same OS+arch as that of the target machine (where the bot would eventually run).

---

### Deploy

1. Copy the archive to the remote host.
2. Untar it, edit `etc/yahtzeebot.service`, and enable the systemd service
3. start the systemd service
