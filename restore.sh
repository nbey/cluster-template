#!/bin/sh

# This script is used to copy the production database to a designated database.
# The assumption is that the destination database is a staging database


# Path to store the database snapshot that is downloaded
# The download will be extracted and restored into the db
# The file will be deleted after the restore
base_path=~/tmp/production/snapshots

# Timestamp for the snapshot download
# This will be used for the directory that the snapshot is downloaded to
# In the event that the download is not deleted, we will know when it was downloaded
unix_time=`date +%s`

# Full download path
complete_download_path="$base_path/$unix_time"

# Restic Snapshot filename
if [ -z "$RESTIC_FILENAME" ]; then
  restic_filename=$RESTIC_FILENAME
else
  restic_filename="indevets-core-partial.sql.gz"
fi


# Let's create the directory if it doesn't exist
# It is likly non-existant because we are using a timestamp as the directory name
mkdir -p "$complete_download_path"

# The function that will clean up what we did at the end
clean_up() {
  cd $base_path
  rm -rf $unix_time
}

# SANITY CHECKS START
# Make sure that the binaries we need are installed

# The ideal choice is to grab the latest data is using restic
# Restic is a backup tool that is used to backup the production database
# But we need to make sure that the restic binary is available
# Restic docs can be found here: https://restic.readthedocs.io/en/stable/
if ! [ -x "$(command -v restic)" ]; then
  echo 'Error: restic is not installed.' >&2
  exit 1
fi

# Requiring gunzip to be installed because I want to download the compressed version of
# the backup. This will help to save on bandwidth
if ! [ -x "$(command -v gunzip)" ]; then
  echo 'Error: Gunzip is not installed. This is needed to extract the download' >&2
  exit 1
fi
# SANITY CHECKS END

# Requesting necessary information for connections
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo 'AWS Access Key ID is required.'
#   echo 'Please enter the AWS Access Key ID (or ctl-c to exit):'
#   read access_key_id
#   export AWS_ACCESS_KEY_ID=$access_key_id
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo 'AWS Secret Access Key is required.'
#     echo 'Please enter the AWS Secret Access Key (or ctl-c to exit):'
#     read secret_access_key
#     export AWS_SECRET_ACCESS_KEY=$secret_access_key
    exit 1
fi

if [ -z "$RESTIC_REPOSITORY" ]; then
    echo 'Restic repository is required.'
#     echo 'Please enter Restic repository (or ctl-c to exit):'
#     read restic_repo
#     export RESTIC_REPOSITORY=$restic_repo
    exit 1
fi

if [ -z "$RESTIC_PASSWORD" ]; then
    echo 'Restic password is required.'
#     echo 'Please enter the Restic password (or ctl-c to exit):'
#     read restic_password
#     export RESTIC_PASSWORD=$restic_password
    exit 1
fi

if [ -z "$DB_HOST" ]; then
    echo '\nDB Host is required.'
#     echo 'Please enter the host (or ctl-c to exit):'
#     read db_host
#     export DB_HOST=$db_host
    exit 1
fi

if [ -z "$DB_DATABASE" ]; then
    echo '\nDB Database is required.'
#     echo 'Please enter the database (or ctl-c to exit):'
#     read db_database
#     export DB_DATABASE=$db_database
    exit 1
fi

if [ -z "$DB_USERNAME" ]; then
    echo '\nDB Username is required.'
#     echo 'Please enter the username (or ctl-c to exit):'
#     read db_username
#     export DB_USERNAME=$db_username
    exit 1
fi

if [ -z "$PGPASSWORD" ]; then
    echo '\nPGPassword is required.'
#     echo 'Please enter the password (or ctl-c to exit):'
#     read db_password
#     export DB_PASSWORD=$db_password
    exit 1
fi

# Let's test the postgres connection first
pg_isready \
    -d $DB_DATABASE \
    -h $DB_HOST \
    -U $DB_USERNAME

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error with postgres connection"
    exit 1
fi

# Let's get the process started
# We will download the latest snapshot for the production database
echo '\n\n'
echo 'Fetching latest snapshot data from production...'
echo '-----------------------------------------------\n'

# Download the latest snapshot with restic
restic restore latest -v -t $complete_download_path

# Let's make sure that the download was successful
if [[ ! -f "$complete_download_path/$restic_filename" ]]; then
  echo 'Error: The snapshot was not downloaded successfully.' >&2
  exit 1
fi

# Let's navigate to the download directory
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

#Extract the snapshot
echo '\n\n'
echo 'Extracting the snapshot...'
echo '-------------------------\n\n'

# We are going to keep the original file just in case
gunzip --keep $complete_download_path/$restic_filename

# Outputting some information about the download
echo "Snapshot downloaded and extracted successfully to $complete_download_path"
echo "Details of the snapshot:"
du -ah $complete_download_path

echo '\n\n'


# Let's start the restore process

# Prevent connections to the DB
psql \
    -d postgres \
    -h $DB_HOST \
    -U $DB_USERNAME \
    -c "ALTER DATABASE $DB_DATABASE WITH ALLOW_CONNECTIONS false;";

# Terminate all connections to the DB
psql \
    -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_DATABASE';"

# We need to get rid of the existing database
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

# Now that we got rid of the database, we can create a new one
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
    -f $complete_download_path/$restic_filename

# In testing I provided the option to not clean up
# Since this is moving to production, I am going to remove the option to NOT clean up
# If you would like to keep the snapshot, you can comment out the following lines
# Otherwise, the snapshot will be deleted after the restore is complete

# while true; do

# echo "\n\n"
# read -p "Would you like to clean up now (delete download)? (y/n) " yn

# case $yn in
# 	[yY] ) echo "Cleaning up..."; clean_up; break;;
# 	[nN] ) break;;
# 	* ) echo invalid response;;
# esac

# done

 echo "\nCleaning up..."
 clean_up()

echo "\n\nAll done. Thank you for allowing me to help today."
echo "Have a great day!"
