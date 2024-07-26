# 🚀 Bluebird Core Quick install scripts ✨

This script is a convenient bootstrap script to install Bluebird Core on Debian systems.
The script executes the steps documented in [Installation and Configuration guide](https://docs.opennms.com/horizon/latest/deployment/core/getting-started.html).

The script is tested with:

* Ubuntu 24.04 (Noble Numba) x86_64
* Debian 12 (Bookworm) x86_64

[![asciicast](https://asciinema.org/a/dCzY67dR6Ph07X2XLEdoGe9FC.svg)](https://asciinema.org/a/dCzY67dR6Ph07X2XLEdoGe9FC)

💁‍♀️ If you want to learn in detail take a look into the deployment section in our documentation for [Bluebird](https://docs.opennms.com/horizon/latest/).

## 🎯 Scope

* Bootstrap a single-node Bluebird Core system on DEB-based systems quickly with the latest stable release
* Installation procedure is close following the best practices from our official docs
* Scripts don't deal with existing installations or upgrades
* Scripts doesn't configure or install Minions, Sentinels, or distributed time series storage like Cortex.
* Users can use the installed system to learn and investigate how to configure Bluebird Core in complex distributed environments which gives them a quick starting point.

## 🏆 Goal

* Give people a way to install Bluebird Core on their system to get familiar with Bluebird Core quickly on a bare metal system.
* Remove the need to know Docker or Ansible to quickly bootstrap a Bluebird Core system.
* Keep it simple and support operating systems based on official packages using DEB.

## 🕹️ Usage

Download the script to your system.

Execute on Debian-based system
```bash
sudo bash bootstrap-debian.sh
```

## 👋 Say hello
You are very welcome to join us to make this repo a better place.
You can find us at:

* Public OpenNMS [Mattermost Chat](https://chat.opennms.com/opennms/channels/opennms-discussion)
* If you have longer discussions to share ideas use our [OpenNMS Discourse](https://opennms.discourse.group) and tag your post with `opennms-installer`
