#!/bin/bash

# fork from https://github.com/route1337/jamf-macos-scripts/blob/main/scripts/Enrollment/installHomebrew.sh
# replaced various sudo with runAsUser
# replaced CurrentUser from python to show State:
# full path to all chmod, chown etc
# proper output suppression for xcodebuild

# Script Name: installHomebrew.sh
# Function: Deploy Homebrew (brew.sh) to the first user added to a new Mac during the post-DEP enrollment DEPNotify run
# Requirements: DEP, Jamf
#
# Copyright 2020, Route 1337 LLC, All Rights Reserved.
#
# Maintainers:
# - Matthew Ahrenstein: matthew@route1337.com
#
# Contributors:
# - "Dakr-xv": https://github.com/Dakr-xv
#
# Using MIT Licensed Code From:
# - "rtrouton": https://github.com/rtrouton
#
# See LICENSE
#

# Check if Apple Silicon
if [ "$(uname -m)" == "arm64" ]; then
	IS_ARM=1
	BREW_BIN_PATH="/opt/homebrew/bin"
else
	IS_ARM=0
	BREW_BIN_PATH="/usr/local/bin"
fi

# current user
ConsoleUser="$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )"

# uid
uid=$(id -u "$ConsoleUser")

runAsUser() {  
  if [ "$ConsoleUser" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$ConsoleUser" "$@"
  else
    echo "no user logged in"
    # uncomment the exit command
    # to make the function exit with an error when no user is logged in
    # exit 1
  fi
} 

### Script from rtrouton ###
# Source: https://github.com/ryangball/rtrouton_scripts/blob/main/rtrouton_scripts/install_xcode_command_line_tools/install_xcode_command_line_tools.sh

# Installing the latest Xcode command line tools on 10.9.x or higher
ignoreBeta="true"	# Setting to true will ignore beta. However, setting to false does not guarantee a beta is available.
# Save current IFS state
OLDIFS=$IFS
IFS='.' read osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
# restore IFS to previous state
IFS=$OLDIFS
cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

if [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -ge 9 ) || ( ${osvers_major} -ge 11 && ${osvers_minor} -ge 0 ) ]]; then

	# Create the placeholder file which is checked by the softwareupdate tool
	# before allowing the installation of the Xcode command line tools.

	touch "$cmd_line_tools_temp_file"

	# Identify the correct update in the Software Update feed with "Command Line Tools" in the name for the OS version in question.

	if [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -ge 15 ) || ( ${osvers_major} -ge 11 && ${osvers_minor} -ge 0 ) ]]; then
	   cmd_line_tools=$(softwareupdate -l | awk '/\*\ Label: Command Line Tools/ { $1=$1;print }' | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 9-)
	elif [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -gt 9 ) ]] && [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -lt 15 ) ]]; then
	   cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | grep "$osvers_minor" | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
	elif [[ ( ${osvers_major} -eq 10 && ${osvers_minor} -eq 9 ) ]]; then
	   cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | grep "Mavericks" | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
	fi

	# Check to see if the softwareupdate tool has returned more than one Xcode
	# command line tool installation option. If it has, use the last one listed
	# as that should be the latest Xcode command line tool installer.

	if (( $(grep -c . <<<"$cmd_line_tools") > 1 )); then
	   cmd_line_tools_output="$cmd_line_tools"
	   cmd_line_tools=$(printf '..%s..' "$cmd_line_tools_output" | tail -1)
	fi
	#Install the command line tools
	softwareupdate -i "$cmd_line_tools" --verbose
	# Remove the temp file
	if [[ -f "$cmd_line_tools_temp_file" ]]; then
	  rm "$cmd_line_tools_temp_file"
	fi
fi

# temporarily add exclusions to mdatp? nope, managed from console
# /usr/local/bin/mdatp exclusion folder add --path /usr/local/*

### Script from rtrouton ###

# Test if Homebrew is installed and install it if it is not
### INSTALL HOMEBREW ###
echo "Checking if Homebrew is installed..."
if test ! "$(sudo -u "${ConsoleUser}" which brew)"; then
    if [[ "$IS_ARM" == 0 ]];then
      echo "Installing x86_64 Homebrew..."
      # Manually install the initial Homebrew
      /bin/mkdir -p /usr/local/Homebrew
      curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /usr/local/Homebrew

      # Core directories
      /bin/mkdir -p /usr/local/Cellar /usr/local/Homebrew /usr/local/Frameworks /usr/local/bin /usr/local/etc /usr/local/Caskroom
      /bin/mkdir -p /usr/local/include /usr/local/lib /usr/local/opt /usr/local/sbin /usr/local/var/homebrew/linked
      /bin/mkdir -p /usr/local/share/zsh/site-functions /usr/local/var
      /bin/mkdir -p /usr/local/share/doc /usr/local/man/man1 /usr/local/share/man/man1
      # /usr/local/bin/mdatp exclusion folder add --path /usr/local/* # temporarily add exclusions to mdatp
      /usr/sbin/chown -R "$ConsoleUser":admin /usr/local/*
      /bin/chmod -Rf g+rwx /usr/local/*
      /bin/chmod 755 /usr/local/share/zsh /usr/local/share/zsh/site-functions

      # Cache directories
      /bin/mkdir -p /Library/Caches/Homebrew
      /bin/chmod g+rwx /Library/Caches/Homebrew
      /usr/sbin/chown "$ConsoleUser":staff /Library/Caches/Homebrew

      # Create a system wide cache folder
      /bin/mkdir -p /Library/Caches/Homebrew
      /bin/chmod g+rwx /Library/Caches/Homebrew
      /usr/sbin/chown "$ConsoleUser":staff /Library/Caches/Homebrew

      # Symlink Homebrew to the usual place
      ln -s /usr/local/Homebrew/bin/brew /usr/local/bin/brew
    else
      echo "Installing arm64 Homebrew..."
      /bin/mkdir -p /opt/homebrew
      curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /opt/homebrew

      # Core directories
      /bin/mkdir -p /opt/homebrew/Cellar /opt/homebrew/Homebrew /opt/homebrew/Frameworks /opt/homebrew/bin /opt/homebrew/etc /opt/homebrew/Caskroom
      /bin/mkdir -p /opt/homebrew/include /opt/homebrew/lib /opt/homebrew/opt /opt/homebrew/sbin /opt/homebrew/var/homebrew/linked
      /bin/mkdir -p /opt/homebrew/share/zsh/site-functions /opt/homebrew/var
      /bin/mkdir -p /opt/homebrew/share/doc /opt/homebrew/man/man1 /opt/homebrew/share/man/man1
      # /usr/local/bin/mdatp exclusion folder add --path /opt/homebrew/* # temporarily add exclusions to mdatp
      /usr/sbin/chown -R "$ConsoleUser":admin /opt/homebrew/*
      /bin/chmod -Rf g+rwx /opt/homebrew/*
      /bin/chmod 755 /opt/homebrew/share/zsh /opt/homebrew/share/zsh/site-functions

      # Cache directories
      /bin/mkdir -p /Library/Caches/Homebrew
      /bin/chmod g+rwx /Library/Caches/Homebrew
      /usr/sbin/chown "$ConsoleUser":staff /Library/Caches/Homebrew

      # Create a system wide cache folder
      /bin/mkdir -p /Library/Caches/Homebrew
      /bin/chmod g+rwx /Library/Caches/Homebrew
      /usr/sbin/chown "$ConsoleUser":staff /Library/Caches/Homebrew

      /bin/chmod -Rf u+rwx /opt/homebrew
      /usr/sbin/chown -Rf "${ConsoleUser}":staff /opt/homebrew
    fi
    # Run an initial update
    runAsUser ${BREW_BIN_PATH}/brew update 2> /dev/null
    # Disable Homebrew analytics
    runAsUser ${BREW_BIN_PATH}/brew analytics off  2> /dev/null
    # Disable Homebrew analytics
    runAsUser ${BREW_BIN_PATH}/brew tap homebrew/cask 2> /dev/null
    # TEST approve xcodebuild license
    runAsUser /usr/bin/xcodebuild -license accept || true
    # add to PATH
    # sudo -H -iu ${ConsoleUser} echo 'export PATH=${BREW_BIN_PATH}:$PATH"' >> ${ConsoleUserHome}/.zshrc

else
    echo "Homebrew already installed."
fi

### END INSTALL HOMEBREW ###
