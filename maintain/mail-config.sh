#!/bin/bash

# Load functions
source maintain/functions.sh

# Set the trap: Call on_exit function when the script exits
trap on_exit EXIT

# If docker is installed - it means restore-command is being run on host
if command -v docker >/dev/null 2>&1; then

  # Add -i if we're in interactive shell
  [[ $- == *i* ]] && bash_flags=(-i) || bash_flags=()

  # Execute restore-command within the container environment passing all arguments, if any
  docker compose exec -it -e TERM="$TERM" wrapper bash "${bash_flags[@]}" "maintain/$(basename "${BASH_SOURCE[0]}")" $@

# Else it means we're in the wrapper-container, so proceed with the restore
else

  # If EMAIL_SENDER_DOMAIN variable is not empty - print DNS-records that are required
  # to be added into settings of each domain mentioned in that variable
  if [[ ! -z "$EMAIL_SENDER_DOMAIN" ]]; then

    # Detect our external IP address
    addr=$(wget -qO- http://ipecho.net/plain)

    # Header line shortcut
    line0="${gray}Type${d}\t${gray}Name${d}\t${gray}Data${d}"

    # Split LETS_ENCRYPT_DOMAIN into an array
    IFS=' ' read -r -a senders <<< "$EMAIL_SENDER_DOMAIN"

    # Iterate over each domain for postfix and opendkim configuration
    for maildomain in "${senders[@]}"; do

      # Print the message for distinction between the records for different domains
      echo
      echo -e "DNS-records required to be added for ${g}$maildomain${d}:"
      echo

      # Get DKIM-key
      dkim=$(cat /etc/opendkim/keys/$maildomain/mail.txt)

      # Strip everything except the key value itself
      dkim=$(echo "$dkim" | sed -E 's~"~~g' | tr -d '\n' | grep -oP 'v=DKIM[^)]+' | sed -E 's~\s{2,}~ ~g')

      # Prepare lines
      line1="MX\t@\tblackhole.io"
      line2="TXT\t@\tv=spf1 a mx ip4:$addr ~all"
      line3="TXT\t_dmarc\tv=DMARC1; p=none"
      line4="TXT\tmail._domainkey\t$dkim"

      # Display the data as a table
      echo -e "$line0\n$line1\n$line2\n$line3\n$line4" | column -t -s $'\t'

    done
    echo
    echo -e "${g}NOTE:${d} If you already have MX-record existing in your DNS-settings"
    echo "      then don't add the one mentioned above"
    echo
    echo -e "${g}NOTE:${d} If you already have TXT-record having Data starting with 'v=spf1'"
    echo "      then amend the existing record to append new IP to the existing one,"
    echo "      e.g. 'ip4:<existing-ip> ip4:$addr'"
    echo
  else
    echo "No domain names were specified in \$EMAIL_SENDER_DOMAIN variable"
  fi
fi
