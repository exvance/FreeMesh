#!/bin/sh
#
# This file is based on Commotion, Copyright (c) 2013, Josh King 
# 
# Commotion is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
# 
# Commotion is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with Commotion.  If not, see <http://www.gnu.org/licenses/>.

BUILDROOT_GIT="https://git.lede-project.org/source.git"

if [ -n "$1" ]; then
  if [ -d buildconfigs/$1 ]; then
    BUILD="$1"
    echo "Using buildconfig $1"
  else
    echo "Invalid buildconfig parameter"
    echo "Usage: ./setup.sh [router build]"
    echo "Check the buildconfigs directory for a list of available builds"
    exit 1
  fi
fi

umask 022
git clone "$BUILDROOT_GIT" build

cd build

[ ! -e feeds.conf ] && cp -v ../feeds.conf feeds.conf
[ ! -e files ] && mkdir files
cp -rf -v ../default-files/* files/

scripts/feeds update -a
scripts/feeds install -a

if [ -n "$BUILD" ]; then
  echo "Copying over build-specific files for $BUILD"
  [ -f ../buildconfigs/$BUILD/diffconfig ] && cp -v ../buildconfigs/$BUILD/diffconfig .config
  [ -d ../buildconfigs/$BUILD/files ] && cp -rf -v ../buildconfigs/$BUILD/files/* files/
	make defconfig
fi

echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo " FreeMesh is prepared. To build the firmware, type:"
echo " cd build"
echo " make menuconfig #If you wish to add or change packages."
echo " make V=s"
echo " "
echo " All build outputs will be build/bin."
