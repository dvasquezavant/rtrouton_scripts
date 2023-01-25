#!/bin/bash

# This script imports a list of Jamf Pro ID numbers from a plaintext file 
# and uses that information to generate a report about the matching computers'
# FileVault personal recovery keys.
#
# Usage: /path/to/generate_filevault_recovery_key_report_from_jamf_pro_id_numbers.sh jamf_pro_id_numbers.txt
#
# Once the Jamf Pro ID numbers are read from in from the plaintext file, the script takes the following actions:
#
# 1. Uses the Jamf Pro API to download all information about the matching computer inventory record in XML format.
# Once the Jamf Pro ID numbers are read from in from the plaintext file, the script takes the following actions:
#
# 1. Uses the Jamf Pro API to download information about the matching computer inventory record in XML format.
# 2. Pulls the following information out of the inventory entry:
#
#    Manufacturer
#    Model
#    Serial Number
#    Hardware UDID
#
# 3. Runs a separate API call to retrieve the following in JSON format.
#
#    FileVault personal recovery key
#
# 4. Create a report in tab-separated value (.tsv) format which contains the following information
#    about the relevant Macs
#
#    Jamf Pro ID
#    Assigned user's username
#    Assigned user's name
#    Assigned user's email address
#    Manufacturer
#    Model
#    Serial Number
#    Hardware UDID
#    If FileVault personal recovery key is available
#    Jamf Pro URL for the computer inventory record

report_file="$(mktemp).tsv"

GetJamfProAPIToken() {

# This function uses Basic Authentication to get a new bearer token for API authentication.

# Use user account's username and password credentials with Basic Authorization to request a bearer token.

if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
   api_token=$(/usr/bin/curl -X POST --silent -u "${jamfpro_user}:${jamfpro_password}" "${jamfpro_url}/api/v1/auth/token" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
else
   api_token=$(/usr/bin/curl -X POST --silent -u "${jamfpro_user}:${jamfpro_password}" "${jamfpro_url}/api/v1/auth/token" | plutil -extract token raw -)
fi

}

APITokenValidCheck() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

api_authentication_check=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "${jamfpro_url}/api/v1/auth" --request GET --header "Authorization: Bearer ${api_token}")

}

CheckAndRenewAPIToken() {

# Verify that API authentication is using a valid token by running an API command
# which displays the authorization details associated with the current API user. 
# The API call will only return the HTTP status code.

APITokenValidCheck

# If the api_authentication_check has a value of 200, that means that the current
# bearer token is valid and can be used to authenticate an API call.

if [[ ${api_authentication_check} == 200 ]]; then

# If the current bearer token is valid, it is used to connect to the keep-alive endpoint. This will
# trigger the issuing of a new bearer token and the invalidation of the previous one.

      if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
         api_token=$(/usr/bin/curl "${jamfpro_url}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${api_token}" | python -c 'import sys, json; print json.load(sys.stdin)["token"]')
      else
         api_token=$(/usr/bin/curl "${jamfpro_url}/api/v1/auth/keep-alive" --silent --request POST --header "Authorization: Bearer ${api_token}" | plutil -extract token raw -)
      fi

else

# If the current bearer token is not valid, this will trigger the issuing of a new bearer token
# using Basic Authentication.

   GetJamfProAPIToken
fi
}

FileVaultRecoveryKeyValidCheck() {

# Verify that a FileVault recovery key is available by running an API command
# which checks if there is a FileVault recovery key present.
#
# The API call will only return the HTTP status code.

filevault_recovery_key_check=$(/usr/bin/curl --write-out %{http_code} --silent --output /dev/null "${jamfpro_url}/api/v1/computers-inventory/$ID/filevault" --request GET --header "Authorization: Bearer ${api_token}")

}

FileVaultRecoveryKeyRetrieval() {

# Retrieves a FileVault recovery key from the computer inventory record.

if [[ $(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}') -lt 12 ]]; then
   filevault_recovery_key_retrieved=$(/usr/bin/curl -sf --header "Authorization: Bearer ${api_token}" "${jamfpro_url}/api/v1/computers-inventory/$ID/filevault" -H "Accept: application/json" | python -c 'import sys, json; print json.load(sys.stdin)["personalRecoveryKey"]')
else
   filevault_recovery_key_retrieved=$(/usr/bin/curl -sf --header "Authorization: Bearer ${api_token}" "${jamfpro_url}/api/v1/computers-inventory/$ID/filevault" -H "Accept: application/json" | plutil -extract personalRecoveryKey raw -)
fi
}

# If you choose to hardcode API information into the script, set one or more of the following values:
#
# The username for an account on the Jamf Pro server with sufficient API privileges
# The password for the account
# The Jamf Pro URL

# Set the Jamf Pro URL here if you want it hardcoded.
jamfpro_url=""	    

# Set the username here if you want it hardcoded.
jamfpro_user=""

# Set the password here if you want it hardcoded.
jamfpro_password=""	

# If you do not want to hardcode API information into the script, you can also store
# these values in a ~/Library/Preferences/com.github.jamfpro-info.plist file.
#
# To create the file and set the values, run the following commands and substitute
# your own values where appropriate:
#
# To store the Jamf Pro URL in the plist file:
# defaults write com.github.jamfpro-info jamfpro_url https://jamf.pro.server.goes.here:port_number_goes_here
#
# To store the account username in the plist file:
# defaults write com.github.jamfpro-info jamfpro_user account_username_goes_here
#
# To store the account password in the plist file:
# defaults write com.github.jamfpro-info jamfpro_password account_password_goes_here
#
# If the com.github.jamfpro-info.plist file is available, the script will read in the
# relevant information from the plist file.
jamf_plist="$HOME/Library/Preferences/com.github.jamfpro-info.plist"

if [[ -r "$jamf_plist" ]]; then

     if [[ -z "$jamfpro_url" ]]; then
          jamfpro_url=$(defaults read "${jamf_plist%.*}" jamfpro_url)
     fi

     if [[ -z "$jamfpro_user" ]]; then
          jamfpro_user=$(defaults read "${jamf_plist%.*}" jamfpro_user)
     fi

     if [[ -z "$jamfpro_password" ]]; then
          jamfpro_password=$(defaults read "${jamf_plist%.*}" jamfpro_password)
     fi

fi

# If the Jamf Pro URL, the account username or the account password aren't available
# otherwise, you will be prompted to enter the requested URL or account credentials.

if [[ -z "$jamfpro_url" ]]; then
     read -p "Please enter your Jamf Pro server URL : " jamfpro_url
fi

if [[ -z "$jamfpro_user" ]]; then
     read -p "Please enter your Jamf Pro user account : " jamfpro_user
fi

if [[ -z "$jamfpro_password" ]]; then
     read -p "Please enter the password for the $jamfpro_user account: " -s jamfpro_password
fi

echo

filename="$1"

# Remove the trailing slash from the Jamf Pro URL if needed.
jamfpro_url=${jamfpro_url%%/}

# Get Jamf Pro API bearer token

GetJamfProAPIToken


progress_indicator() {
  spinner="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  while :
  do
    for i in $(seq 0 7)
    do
      echo -n "${spinner:$i:1}"
      echo -en "\010"
      sleep 0.10
    done
  done
}

echo "Report being generated. File location will appear below once ready."

progress_indicator &

SPIN_PID=$!

trap "kill -9 $SPIN_PID" $(seq 0 15)

while read -r ID; do
			
	if [[ "$ID" =~ ^[0-9]+$ ]]; then
            CheckAndRenewAPIToken

            ComputerRecord=$(/usr/bin/curl -sf --header "Authorization: Bearer ${api_token}" "${jamfpro_url}/JSSResource/computers/id/$ID" -H "Accept: application/xml" 2>/dev/null)

            if [[ ! -f "$report_file" ]]; then
                touch "$report_file"
                printf "Jamf Pro ID Number\tMake\tModel\tSerial Number\tUDID\tFileVault Recovery Key Available\tFileVault Recovery Key\tJamf Pro URL\n" > "$report_file"
            fi

            FileVaultRecoveryKeyValidCheck
            
            if [[ ${filevault_recovery_key_check} == 200 ]]; then
                FileVaultKeyAvailable="Yes"
                FileVaultRecoveryKeyRetrieval
                
              if [[ -n "$filevault_recovery_key_retrieved" ]]; then
                  FileVaultRecoveryKey="$filevault_recovery_key_retrieved"
                else
                  FileVaultRecoveryKey="Error retrieving FileVault recovery key"
              fi
            else
                FileVaultKeyAvailable="No"
                FileVaultRecoveryKey="NA"
            fi
           
            Make=$(echo "$ComputerRecord" | xmllint --xpath '//computer/hardware/make/text()' - 2>/dev/null)
            MachineModel=$(echo "$ComputerRecord" | xmllint --xpath '//computer/hardware/model/text()' - 2>/dev/null)
            SerialNumber=$(echo "$ComputerRecord" | xmllint --xpath '//computer/general/serial_number/text()' - 2>/dev/null)
            UDIDIdentifier=$(echo "$ComputerRecord" | xmllint --xpath '//computer/general/udid/text()' - 2>/dev/null)						
            JamfProURL=$(echo "$jamfpro_url"/computers.html?id="$ID")
			
            if [[ $? -eq 0 ]]; then
                printf "$ID\t$Make\t$MachineModel\t$SerialNumber\t$UDIDIdentifier\t${FileVaultKeyAvailable}\t${FileVaultRecoveryKey}\t${JamfProURL}\n" >> "$report_file"
            else
                echo "ERROR! Failed to read computer record with id $ID"
            fi
	fi
				
done < "$filename"

kill -9 "$SPIN_PID"
			
if [[ -f "$report_file" ]]; then
     echo "Report on Macs available here: $report_file"
fi

exit 0