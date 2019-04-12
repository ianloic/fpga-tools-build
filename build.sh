#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DESTDIR=${DIR}/dest

usage() {
  echo "build.sh help    show this help"
  echo "build.sh deps    install build dependencies"
  echo "build.sh clean   clean up build directories"
  echo "build.sh update  update all deps"
  echo "build.sh build   build tools"
}

if [ $# -ne 1 ]; then
  echo $#
  usage
  exit 1
fi

build() {
  PREFIX=${PREFIX:-/opt/fpga}
  NPROC=$(nproc)
  echo "Building into ${DESTDIR}/${PREFIX}"
  build_icestorm
  build_prjtrellis
  build_yosys
  build_nextpnr_ice40
  build_nextpnr_ecp5
}

build_icestorm() {
  echo "Building icestorm"
  PREFIX=${PREFIX} make -C "${DIR}/icestorm" all
  PREFIX=${PREFIX} DESTDIR=${DESTDIR} make -C "${DIR}/icestorm" install
}

build_prjtrellis() {
  echo "Building project trellis"
  cmake -S "${DIR}/prjtrellis/libtrellis" -B "${DIR}/prjtrellis/libtrellis" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
  PREFIX=${PREFIX} make -C "${DIR}/prjtrellis/libtrellis"
  PREFIX=${PREFIX} DESTDIR=${DESTDIR} make -C "${DIR}/prjtrellis/libtrellis" install
}

build_yosys() {
  echo "Building yosys"
  PREFIX=${PREFIX} make -C "${DIR}/yosys" -j "${NPROC}"
  PREFIX=${PREFIX} DESTDIR=${DESTDIR} make -C "${DIR}/yosys" install
}

build_nextpnr_ice40() {
  echo "Building nextpnr-ice40"
  local ICE40_BUILD="${DIR}/nextpnr/build.ice40"
  cmake -S "${DIR}/nextpnr" -B "${ICE40_BUILD}" -DARCH=ice40 -DICEBOX_ROOT="${DESTDIR}/${PREFIX}/share/icebox" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
  make -C "${ICE40_BUILD}" -j "${NPROC}"
  DESTDIR=${DESTDIR} make -C "${ICE40_BUILD}" install
}

build_nextpnr_ecp5() {
  echo "Building nextpnr/ecp5"
  local ECP5_BUILD="${DIR}/nextpnr/build.ecp5"
  cmake -S "${DIR}/nextpnr" -B "${ECP5_BUILD}" -DARCH=ecp5 -DTRELLIS_ROOT="${DIR}/prjtrellis" -DCMAKE_INSTALL_PREFIX="${PREFIX}"
  make -C "${ECP5_BUILD}" -j "${NPROC}"
  DESTDIR=${DESTDIR} make -C "${ECP5_BUILD}" install
}

case $1 in
  help)
    usage
    ;;
  deps)
    sudo apt-get install \
      build-essential \
      clang \
      cmake \
      bison \
      flex \
      libboost-all-dev \
      libeigen3-dev \
      libftdi-dev \
      libreadline-dev \
      gawk \
      tcl-dev \
      libffi-dev \
      git \
      graphviz \
      pkg-config \
      python3 \
      python3-dev \
      qt5-default
    ;;
  clean)
    git submodule --quiet foreach --recursive 'git clean -ffxd'
    rm -rf "${DESTDIR}"
    ;;
  update)
    git submodule update --recursive --remote
    ;;
  build)
    build
    ;;
  *)
    echo "unknown command '$1'"
    usage
    exit 1
esac
