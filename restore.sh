#!/bin/sh

# This script is used to restore the latest restic snapshot into a DB


# Sanity Checks

# The ideal choice is to grab the latest data is using restic
# Restic is a backup tool that is used to backup the production database
# But we need to make sure that the restic binary is available
# Restic docs can be found here: https://restic.readthedocs.io/en/stable/
if ! [ -x "$(command -v restic)" ]; then
  echo 'Error: restic is not installed.' >&2
  exit 1
fi

# Requiring gunzip for use with compressed snapshots
if ! [ -x "$(command -v gunzip)" ]; then
  echo 'Error: Gunzip is not installed. This is needed to extract the download' >&2
  exit 1
fi

# End Sanity Checks


# Input Variables Check

# AWS Credentials used w/ Restic
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo 'AWS Access Key ID is required.'
  exit 1
fi
if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo 'AWS Secret Access Key is required.'
    exit 1
fi

# Restic Repository Credentials
if [ -z "$RESTIC_REPOSITORY" ]; then
    echo 'Restic repository is required.'
    exit 1
fi
if [ -z "$RESTIC_PASSWORD" ]; then
    echo 'Restic password is required.'
    exit 1
fi

# DB Configuration
if [ -z "$DB_HOST" ]; then
    echo '\nDB Host is required.'
    exit 1
fi
if [ -z "$DB_DATABASE" ]; then
    echo '\nDB Database is required.'
    exit 1
fi
if [ -z "$DB_USERNAME" ]; then
    echo '\nDB Username is required.'
    exit 1
fi

# Postgres Password Configuration
if [ -z "$PGPASSWORD" ]; then
    echo '\nPGPassword is required.'
    exit 1
fi

# DB SSH Credentials
if [ -z "$SSH_KEY_ENCODED" ]; then
    echo '\nSSH_KEY_ENCODED is required.'
    exit 1
fi
if [ -z "$SSH_USERNAME" ]; then
    echo '\nSSH_USERNAME is required.'
    exit 1
fi

# End Input Variables Check


# Path to store the database snapshot that is downloaded
base_path=~/tmp/production/snapshots

# Timestamp for the snapshot download
unix_time=`date +%s`

# Full download path
complete_download_path="$base_path/$unix_time"

# Restic Snapshot filename
if [ -z "$RESTIC_FILENAME" ]; then
  restic_filename=$RESTIC_FILENAME
else
  restic_filename="indevets-core-partial.sql.gz"
fi

# Shortcut for snapshot filepath
snapshot_filepath="$complete_download_path/$restic_filename"

# Let's create the directory if it doesn't exist
mkdir -p "$complete_download_path"

# Setup SSH Connection Credentials
touch ~/db-ssh-key
echo $SSH_KEY_ENCODED | base64 -d > ~/db-ssh-key
chmod 600 ~/db-ssh-key
ssh-keyscan -H $DB_HOST >> ~/.ssh/known_hosts

# Test the SSH Connection
ssh -q -i ~/db-ssh-key $SSH_USERNAME@$DB_HOST exit
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error with SSH connection - "$SSH_USERNAME"@"$DB_HOST
    echo "Return Value: "$retVal
    exit 1
fi

# Test the postgres connection first
pg_isready \
    -d $DB_DATABASE \
    -h $DB_HOST \
    -U $DB_USERNAME

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error with postgres connection"
    exit 1
fi

# We will download the latest snapshot for the production database
echo '\n\n'
echo 'Fetching latest snapshot data from production...'
echo '-----------------------------------------------\n'

# Download the latest snapshot with restic
restic restore latest -v -t $complete_download_path

# Let's make sure that the download was successful
if [[ ! -f "$snapshot_filepath" ]]; then
  echo 'Error: The snapshot was not downloaded successfully.' >&2
  exit 1
fi

cd $complete_download_path

# This may be a bit overkill, but a checksum should scan every byte of the file
# This is a good way to verify that the file was not corrupted during the download
# process. I assume that if there is a problem with a byte, the checksum will fail thus indicating that the file
# is corrupted.
if [ -x "$(command -v cksum)" ]; then

    # Verify the integrity of the data
    echo '\n\n'
    echo 'Verifying integrity of the data...'
    echo '---------------------------------\n'

    if cksum $restic_filename; then
        echo "Checksum of $restic_filename is complete"
        echo 'Moving on...'
    else
        echo 'Error: Chucksum failed. The download may be corrupt. Bailing out.' >&2
        exit 1
    fi
else
  echo 'Warning: Checksum utility is not installed. Skipping checksum verification.'
  echo 'This does not mean that the data is corrupted. It just means that we cannot verify the integrity of the data.'
fi

# Extract the snapshot
echo '\n\n'
echo 'Extracting the snapshot...'
echo '-------------------------\n\n'

gunzip --keep $snapshot_filepath

echo "Snapshot downloaded and extracted successfully to $complete_download_path"
echo "Details of the snapshot:"
du -ah $snapshot_filepath

echo '\n\n'

# Disallow new connections
 psql \
    -d postgres \
    -U $DB_USERNAME \
    -h DB_HOST \
    -c "ALTER DATABASE $DB_DATABASE WITH ALLOW_CONNECTIONS false;"
    
# Kill current connections
ssh \
    $SSH_USERNAME@$DB_HOST \
    -i ~/db-ssh-key \
    -t << EOF
        sudo su - postgres -c \
        'psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '\''$DB_DATABASE'\'';"'
    EOF

# Drop DB
echo '\nDropping the database if it exists so we can start fresh...'
psql \
    -d postgres \
    -h $DB_HOST \
    -U $DB_USERNAME \
    -c "DROP DATABASE IF EXISTS $DB_DATABASE;"

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error with dropping database"
    exit 1
fi

# Create DB
echo '\nCreating the database...'
psql \
    -d postgres \
    -h $DB_HOST \
    -U $DB_USERNAME \
    -c "CREATE DATABASE $DB_DATABASE;"

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error with creating database"
    exit 1
fi

# Re-enable DB Connections
psql \
    -d postgres \
    -h $DB_HOST \
    -U $DB_USERNAME \
    -c "ALTER DATABASE $DB_DATABASE WITH ALLOW_CONNECTIONS true;";

# Quick sanity check to make sure that the database was created
if psql -h $DB_HOST -U $DB_USERNAME -lqt | cut -d \| -f 1 | grep -qw $DB_DATABASE; then
    echo '\n Database appears to have been created successfully. Ready to restore the data.'
else
    echo '\nError: The database does not seem to exist. Maybe we had a problem creating it?' >&2
    exit 1
fi

# Now that we have a database, we can restore the data
echo "Lets import our snapshot to the database"
psql \
    -d $DB_DATABASE \
    -h $DB_HOST \
    -U $DB_USERNAME \
    -f $snapshot_filepath


echo "\n\nAll done. Thank you for allowing me to help today."
echo "Have a great day!"
