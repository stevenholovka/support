#!/bin/zsh

###################################################################################################
# Created by Matt Wilson | se@kandji.io | Kandji, Inc. | Solutions Engineering
###################################################################################################
# Created on 07/30/2021
###################################################################################################
# Software Information
###################################################################################################
# This script is designed to check if an application is present. If the app is present, the
# script will check to see if a minimum version is being enforced. If a minimum app version is not
# being enforced, the script will only check to see if the app is installed or not.
###################################################################################################
# License Information
###################################################################################################
# Copyright 2021 Kandji, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
# to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
###################################################################################################

# Script version
VERSION="1.0.0"

###################################################################################################
###################################### VARIABLES ##################################################
###################################################################################################
# If you would like to enforce a minimum version, be sure to update the MINIMUM_ENFORCED_VERSION variable
# with the version number that the audit script should enforce. (Example version number
# 1.5.207.0). If MINIMUM_ENFORCED_VERSION is left blank, the audit script will not check for a version and
# will only check for the presence of the Cloudflare WARP app at the defined APP_PATH.
MINIMUM_ENFORCED_VERSION="1.5.207.0"

###################################################################################################

# Make sure that the application matches the name of the app that will be installed.
# This script will dynamically search for the application in the Applications folder. So
# there is no need to define an application path. The app must either install in the
# Applications folder or up to 3 sub-directories deep.
#   For example Applications/<app_folder_name>/<app_name.app>
APP_NAME="Cloudflare WARP.app"

# Change the PROFILE_PAYLOAD_ID_PREFIX variable to the profile prefix you want to wait on before
# running the installer. If the profile is not found, this audit and enforce script will exit 00
# and do nothing until the next kandji agent check-in.
PROFILE_PAYLOAD_ID_PREFIX="io.kandji.cloudflare.C59FD676"

###################################################################################################
###################################### FUNCTIONS ##################################################
###################################################################################################

return_installed_app_version() {
    # Return the currently installed application version
    #
    # $1 - Is the name of the application.
    local app_name="$1"
    local installed_version="" # Initialize local variable

    # Uses the find binary to look for the app inside of the Applications directory and
    # any subdirectories up to 3 levels deep.
    local find_app="$(/usr/bin/find /Applications -maxdepth 3 -name $app_name)"
    local ret="$?"

    # Check to see if the app is installed.
    if [[ "$ret" -eq 0 ]] && [[ -d "$find_app" ]] &&
        [[ "$app_name" == "$(/usr/bin/basename $find_app)" ]]; then
        # If the previous command returns true and the returned object is a directory
        # and the app name that we are looking for is exactly equal to the app name
        # found by the find command.

        # Gets the installed app version and replaces any "-" with "."
        installed_version=$(/usr/bin/defaults read \
            "$find_app/Contents/Info.plist" CFBundleShortVersionString |
            /usr/bin/sed "s/-/./g")

    else
        installed_version="None"
    fi

    echo "$installed_version"
}

###################################################################################################
###################################### MAIN LOGIC #################################################
###################################################################################################

# All of the main logic be here ... modify at your own risk.

# The profiles variable will be set to an array of profiles that match the prefix in
# the PROFILE_PAYLOAD_ID_PREFIX variable
profiles=$(/usr/bin/profiles show | grep "$PROFILE_PAYLOAD_ID_PREFIX" | sed 's/.*\ //')

# If the PROFILE_PAYLOAD_ID_PREFIX is not found, exit 0 to wait for the next agent run.
if [[ ${#profiles[@]} -eq 0 ]]; then
    echo "no profiles with ID $PROFILE_PAYLOAD_ID_PREFIX were found ..."
    echo "Waiting until the profile is installed before proceeding ..."
    echo "Will check again at the next Kandji agent check-in ..."
    exit 0

else
    echo "Profile prefix $PROFILE_PAYLOAD_ID_PREFIX present ..."

    # Uses the find binary to look for the app inside of the Applications directory and
    # any subdirectories up to 3 levels deep.
    find_app="$(/usr/bin/find /Applications -maxdepth 3 -name $APP_NAME)"
    ret="$?"

    # Check to see if the app is installed.
    if [[ "$ret" -eq 0 ]] && [[ -d "$find_app" ]] &&
        [[ "$APP_NAME" == "$(/usr/bin/basename $find_app)" ]]; then
        # If the previous command returns true and the returned object is a directory
        # and the app name that we are looking for is exactly equal to the app name
        # found by the find command.
        echo "$find_app was found ..."

        # Check to see if an MINIMUM_ENFORCED_VERSION is set. If not, exit 0.
        if [[ "$MINIMUM_ENFORCED_VERSION" == "" ]]; then
            echo "A minimum enforced version is not set ..."
            exit 0
        fi

        # Get the currently install version
        # Pass the APP_NAME variable from above to the return_installed_app_version function
        # Removing the periods from the version number so that we can make a comparison.
        installed_version="$(return_installed_app_version $APP_NAME | /usr/bin/sed 's/\.//g')"

        # Removing the periods from the version number so that we can make a comparison.
        enforced_version="$(echo $MINIMUM_ENFORCED_VERSION | /usr/bin/sed 's/\.//g')"

        # Check to see if the installed_version is less than the enforced_version. If it is then
        # exit 1 to initiate the installation process.
        if [[ "$installed_version" -lt "$enforced_version" ]]; then
            echo "Installed app version $installed_version less than enforced verison $MINIMUM_ENFORCED_VERSION"
            echo "Starting the app install process ..."
            exit 1

        else
            echo "Enforced vers: $enforced_version"
            echo "Installed app version: $installed_version"
            echo "Minimum app version enforcement met ..."
            echo "No need to run the installer ..."
            exit 0
        fi

    else
        echo "$APP_NAME was not found in the Applications folder ..."
        echo "Need to install $APP_NAME ..."
        exit 1

    fi

fi

exit 0
