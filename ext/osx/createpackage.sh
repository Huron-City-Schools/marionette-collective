#!/bin/bash
#
# Script to build an "old style" not flat pkg out of the mcollective repository.
#
# Author: Nigel Kersten (nigelk@google.com)
#
# Last Updated: 2008-07-31
#
# Copyright 2008 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License


RAKEFILE="Rakefile"
MPATH=''
MCLIBDIR='/usr/libexec/'
MCDOCDIR='/usr/share/doc/mcollective'
LAUNCHDIR='/Library/LaunchDaemons'
ETCDIR='/etc/mcollective'
BINDIR="/usr/bin"
SBINDIR="/usr/sbin"
SITELIBDIR="/usr/lib/ruby/site_ruby/1.8"
PACKAGEMAKER="/Developer/usr/bin/packagemaker"
PROTO_PLIST="PackageInfo.plist"
PREFLIGHT="preflight"


function find_installer() {
  # we walk up three directories to make this executable from the root,
  # root/conf or root/conf/osx
  if [ -f "./${RAKEFILE}" ]; then
    installer="$(pwd)/${RAKEFILE}"
  elif [ -f "../${RAKEFILE}" ]; then
    installer="$(pwd)/../${RAKEFILE}"
  elif [ -f "../../${RAKEFILE}" ]; then
    installer="$(pwd)/../../${RAKEFILE}"
  else
    installer=""
  fi
}

function find_mcollective_root() {
  mcollective_root=$(dirname "${installer}")
}

function install_mcollective() {
  # Create the required package locations.
  mkdir -p ${pkgroot}${MCLIBDIR}  
  mkdir -p ${pkgroot}${MCDOCDIR}
  mkdir -p ${pkgroot}${LAUNCHDIR}
  mkdir -p ${pkgroot}${BINDIR}
  mkdir -p ${pkgroot}${SBINDIR}
  mkdir -p ${pkgroot}${SITELIBDIR}
  mkdir -p ${pkgroot}${ETCDIR}

  # Copy executables to the $SBINDIR
  # Set mode to make them executable
  cp ${mcollective_root}/mc-* ${pkgroot}/${SBINDIR}
  chmod 755 ${pkgroot}/${SBINDIR}

  # Copy files to $ETCDIR and remove ".dist"
  # Set root:wheel permissions and a mode of 700
  # to the *.cfg files in $ETCDIR
  for file in ${mcollective_root}/etc/* ; do cp -R ${file} $(echo ${pkgroot}/${ETCDIR}/`basename ${file}` | sed 's/.dist//g') ; done
  chown root:wheel ${pkgroot}/${ETCDIR}/*.cfg
  chmod 700 ${pkgroot}/${ETCDIR}/*.cfg

  # Copy files to $MCLIBDIR
  cp -R ${mcollective_root}/plugins/* ${pkgroot}/${MCLIBDIR}

  # Copy files to $SITELIBDIR
  cp -R ${mcollective_root}/lib/* ${pkgroot}/${SITELIBDIR}

  # Copy a sample launchd property list file to $LAUNCHDIR
  # also set the permissions correctly.
  cat - > ${pkgroot}/${LAUNCHDIR}/org.marionette-collective.mcollective.plist <<EOF
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
          <key>EnvironmentVariables</key>
          <dict>
                  <key>PATH</key>
                  <string>/sbin:/usr/sbin:/bin:/usr/bin</string>
                  <key>RUBYLIB</key>
                  <string>/Library/Ruby/Site/1.8</string>
          </dict>
          <key>Label</key>
          <string>org.marionette-collective.mcollective</string>
          <key>OnDemand</key>
          <false/>
          <key>KeepAlive</key>
          <true/>
          <key>ProgramArguments</key>
          <array>
                  <string>/usr/sbin/mcollectived</string>
                  <string>--config=/etc/mcollective/server.cfg</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>ServiceDescription</key>
          <string>MCollective Server</string>
          <key>ServiceIPC</key>
          <false/>
  </dict>
  </plist>
EOF

  chmod 644 ${pkgroot}/${LAUNCHDIR}/org.marionette-collective.mcollective.plist

  # echo "Installing MCollective to ${pkgroot}"
  # "${installer}" --destdir="${pkgroot}" --bindir="${BINDIR}" --sbindir="${SBINDIR}" --sitelibdir="${SITELIBDIR}"
  # chown -R root:admin "${pkgroot}"
}

function install_docs() {
  echo "Installing docs to ${pkgroot}"
  docdir="${pkgroot}/usr/share/doc/mcollective" 
  mkdir -p "${docdir}"
  for docfile in COPYING README; do
    install -m 0644 "${mcollective_root}/${docfile}" "${docdir}"
  done
  chown -R root:wheel "${docdir}"
  chmod 0755 "${docdir}"
}

function get_mcollective_version() {
  mcollective_version=$(RUBYLIB="${pkgroot}/${SITELIBDIR}:${RUBYLIB}" ruby -e "require 'mcollective'; puts MCollective.version")
}

function prepare_package() {
  # As we can't specify to follow symlinks from the command line, we have
  # to go through the hassle of creating an Info.plist file for packagemaker
  # to look at for package creation and substitue the version strings out.
  # Major/Minor versions can only be integers, so we have "0" and "410" for
  # mcollective version 0.4.10. If "@DEVELOPMENT_VERSION@" is the current
  # version, we will use 0.4.10 as our current version.
  # Note too that for 10.5 compatibility this Info.plist *must* be set to
  # follow symlinks.
  if [ $(echo ${mcollective_version}) == "@DEVELOPMENT_VERSION@" ]; then
	VER1="0"
	VER2="4"
	VER3="10"
  else
	VER1=$(echo ${mcollective_version} | awk -F "." '{print $1}')
    VER2=$(echo ${mcollective_version} | awk -F "." '{print $2}')
    VER3=$(echo ${mcollective_version} | awk -F "." '{print $3}')
  fi

  major_version="${VER1}"
  minor_version="${VER2}${VER3}"
  cp "${mcollective_root}/ext/osx/${PROTO_PLIST}" "${pkgtemp}"
  sed -i '' "s/{SHORTVERSION}/${mcollective_version}/g" "${pkgtemp}/${PROTO_PLIST}"
  sed -i '' "s/{MAJORVERSION}/${major_version}/g" "${pkgtemp}/${PROTO_PLIST}"
  sed -i '' "s/{MINORVERSION}/${minor_version}/g" "${pkgtemp}/${PROTO_PLIST}"

  # We need to create a preflight script to remove traces of previous
  # mcollective installs due to limitations in Apple's pkg format.
  mkdir "${pkgtemp}/scripts"
  cp "${mcollective_root}/ext/osx/${PREFLIGHT}" "${pkgtemp}/scripts"

  # substitute in the sitelibdir specified above on the assumption that this
  # is where any previous mcollective install exists that should be cleaned out.
  sed -i '' "s|{SITELIBDIR}|${SITELIBDIR}|g" "${pkgtemp}/scripts/${PREFLIGHT}"
  # substitute in the bindir sepcified on the assumption that this is where
  # any old executables that have moved from bindir->sbindir should be
  # cleaned out from.
  sed -i '' "s|{BINDIR}|${BINDIR}|g" "${pkgtemp}/scripts/${PREFLIGHT}"
  chmod 0755 "${pkgtemp}/scripts/${PREFLIGHT}"
}

function create_package() {
  rm -fr "$(pwd)/mcollective-${mcollective_version}.pkg"
  echo "Building package"
  echo "Note that packagemaker is reknowned for spurious errors. Don't panic."
  "${PACKAGEMAKER}" --root "${pkgroot}" \
                    --info "${pkgtemp}/${PROTO_PLIST}" \
                    --scripts ${pkgtemp}/scripts \
                    --out "$(pwd)/mcollective-${mcollective_version}.pkg"
  if [ $? -ne 0 ]; then
    echo "There was a problem building the package."
    cleanup_and_exit 1
    exit 1
  else
    echo "The package has been built at:"
    echo "$(pwd)/mcollective-${mcollective_version}.pkg"
  fi
}

function cleanup_and_exit() {
  if [ -d "${pkgroot}" ]; then
    rm -fr "${pkgroot}"
  fi
  if [ -d "${pkgtemp}" ]; then
    rm -fr "${pkgtemp}"
  fi
  exit $1
}

# Program entry point
function main() {

  if [ $(whoami) != "root" ]; then
    echo "This script needs to be run as root via su or sudo."
    cleanup_and_exit 1
  fi

  find_installer

  if [ ! "${installer}" ]; then
      echo "Unable to find ${RAKEFILE}"
      cleanup_and_exit 1
    fi

  find_mcollective_root

  if [ ! "${mcollective_root}" ]; then
    echo "Unable to find mcollective repository root."
    cleanup_and_exit 1
  fi

  pkgroot=$(mktemp -d -t mcollectivepkg)

  if [ ! "${pkgroot}" ]; then
    echo "Unable to create temporary package root."
    cleanup_and_exit 1
  fi

  pkgtemp=$(mktemp -d -t mcollectivetmp)

  if [ ! "${pkgtemp}" ]; then
    echo "Unable to create temporary package root."
    cleanup_and_exit 1
  fi

  install_mcollective
  install_docs
  get_mcollective_version

  if [ ! "${mcollective_version}" ]; then
    echo "Unable to retrieve mcollective version"
    cleanup_and_exit 1
  fi

  prepare_package
  create_package

  cleanup_and_exit 0
}

main "$@"