#!/bin/sh
git clone https://gitlab.com/WhyNotHugo/darkman.git
cd darkman
make
sudo make install PREFIX=/usr