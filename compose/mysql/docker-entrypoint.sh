#!/bin/bash
set -eu -o pipefail

# If wget is not yet installed
if ! command -v wget &>/dev/null; then

  # Install it
  apt-get update && apt-get install -y wget

  # Print which dump is going to be imported
  echo "MYSQL_DUMP is '$MYSQL_DUMP'";

  # Change dir
  cd /docker-entrypoint-initdb.d

  # Array of other sql files to be imported
  declare -a import=("maxwell.sql")

  # Split MYSQL_DUMP on whitespace into an array
  IFS=' ' read -ra dumpA <<< "$MYSQL_DUMP"

  # Empty dumps counter
  empty=0

  # Downloaded/copied dumps counter, to be used in filename prefix to preserve import order
  prefix=0

  # Foreach dump
  for dump in "${dumpA[@]}"; do

    # If dump is an URL
    if [[ $dump == http* ]]; then

      # Extract the filename from the URL and add counter-prefix 
      name="$prefix-$(basename "$dump")"

      # Download it right here
      echo "Fetching remote MySQL dump from '$dump' into local '$name' ..." && wget --no-check-certificate -O "$name" "$dump"

      # Increment saved dumps counter
      prefix=$((prefix + 1))

    # Else assume it's a local path pointing to some file inside
    # /docker-entrypoint-initdb.d/custom/ directory mapped as a volume
    # from sql/ directory on the docker host machine
    else

      # Shortcut
      local="custom/$dump"

      # If that local dump file does NOT really exists in sql/ directory on host machine
      # e.g does NOT exists in custom/ directory in mysql-container due to bind volume mapping
      # but GH_TOKEN variable is set - assume this dump file should be downloaded from github
      if [[ ! -f "$local" && ! -z "$GH_TOKEN" ]]; then

        # Install GitHub CLI, if not yet installed
        if ! command -v gh &>/dev/null; then
          echo "Installing GitHub CLI"
          ghgpg=/usr/share/keyrings/githubcli-archive-keyring.gpg
          apt-get install curl -y
          curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=$ghgpg && chmod go+r $ghgpg
          echo "deb [arch=$(dpkg --print-architecture) signed-by=$ghgpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
          apt update && apt install gh -y
        fi

        # Get repo 'owner/name'
        repo=$(sed -n 's#.*\/\([a-zA-Z0-9_\-]\+\/[a-zA-Z0-9_\-]\+\)\.git#\1#p' .gitconfig | sed -n '1p')

        # Print where we are
        echo "Downloading $dump from '$repo'-repo's assets on github"

        # Download dump
        gh release download latest -D custom -p "$dump" -R "$repo"
      fi

      # If that local dump file really exists in sql/ directory on host machine
      # e.g exists  in custom/ directory in mysql-container due to bind volume mapping
      if [ -f "$local" ]; then

        # If that local dump file is not empty
        if [ -s "$local" ]; then

          # Copy that file here for it to be imported, as files from subdirectories are ignored while import
          cp "$local" "$prefix-$dump" && echo "File '/docker-entrypoint-initdb.d/$local' copied to the level up"

          # Increment saved dumps counter
          prefix=$((prefix + 1))

        # Else
        else

          # Print warning
          echo "[Warning] Local SQL dump file '$dump' is empty"

          # Increment empty dumps counter
          empty=$((empty + 1))
        fi

      # Else if that local dump file does not really exist
      else

        # Print error an exit
        echo "SQL dump file '$dump' is not found!" && exit 1
      fi
    fi
  done

  # If no dump(s) were given by MYSQL_DUMP-variable or all are empty
  if [ $(( ${#dumpA[@]} - empty )) -eq 0 ]; then

    # Use system.sql
    import+=("system.sql") && echo "The file(s) specified by \$MYSQL_DUMP does not exist or is empty, so using system.sql"
  fi

  # Download the SQL dump files
  for filename in "${import[@]}"; do
    url="https://github.com/indi-engine/system/raw/master/sql/${filename}"
    echo "Fetching from $url..." && wget "$url"
  done

  # Spoof mysql user name inside maxwell.sql, if need
  [[ $MYSQL_USER != "custom" ]] && sed -i "s~custom~$MYSQL_USER~" maxwell.sql

  # Create directory and copy 'mysql' and 'mysqldump' command-line utilities into it, so that
  # we can share those two binaries with apache-container to be able to export/import sql-files
  src="/usr/bin"
  vmd="/usr/bin/volumed"
  if [[ ! -d $vmd ]] ; then mkdir $vmd; fi
  cp "$src/mysql"     "$vmd/mysql"
  cp "$src/mysqldump" "$vmd/mysqldump"

  # Append touch-command to create an empty '/var/lib/mysql/init.done'-file after init is done to use in healthcheck
  sed -i 's~Ready for start up."~&\n\t\t\ttouch /var/lib/mysql/init.done~' /usr/local/bin/docker-entrypoint.sh
fi

# Call the original entrypoint script
/usr/local/bin/docker-entrypoint.sh "$@"
