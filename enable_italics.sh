#!/bin/bash

# enable italic characters in the terminal

rm -rf ~/.terminfo
mkdir ~/.terminfo

infocmp screen | sed \
    -e 's/%?%p1%t;3%/%?%p1%t;7%/' \
    -e 's/smso=[^,]*,/smso=\\E[7m,/' \
    -e 's/rmso=[^,]*,/rmso=\\E[27m,/' \
    -e '$s/$/ sitm=\\E[3m, ritm=\\E[23m,/' > /tmp/screen.terminfo
tic /tmp/screen.terminfo

infocmp xterm | sed \
    -e '$s/$/ sitm=\\E[3m, ritm=\\E[23m,/' > /tmp/xterm.terminfo
tic /tmp/xterm.terminfo

echo Testing: `tput sitm`italics`tput ritm` `tput smso`standout`tput rmso`
