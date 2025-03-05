#!/usr/bin/env bash

set -e

git clone https://github.com/arkq/bluez-alsa.git
cd bluez-alsa/ 
sudo apt install -y autoconf autoconf libdbus-1-dev libasound2-dev libbluetooth-dev libtool libglib2.0-dev libdbus-1-dev libsbc-dev libmp3lame-dev
autoreconf --install
mkdir build
cd build
../configure --enable-mp3lame --enable-systemd --with-bluealsauser=$USER
make
sudo make install
sudo systemctl enable bluealsa.service
sudo systemctl start bluealsa.service
sudo systemctl enable bluealsa-aplay.service
sudo systemctl start bluealsa-aplay.service

