#!/bin/bash
# Define Variables
BACKUP_API="http://supervisor/backups"                      # Supervisor backup endpoint
BACKUP_PATH="/tmp/${FILENAME}.tar"                          # Define path where to save the backup file
FILENAME="backup_restored"                                  # Use backup_restored as the backup filename
OLD_BACKUP_VERSION_JSON_PATH="/tmp/backup_version.json"     # Define path to save old backup version json file

# Function to get Mac Address from eth0
get_mac_address() {
    MAC_ADDR=$(ip link show eth0 | awk '/ether/ {print $2}')
    MAC_ADDR=$(echo $MAC_ADDR | tr -d ':')
    echo $MAC_ADDR
}

# Function to save MAC Address to a file
save_mac_address() {
    local MAC_ADDR=$1
    echo $MAC_ADDR > /tmp/mac_address.txt
}

# Function to check backup exists
check_backup_exists() {
    local MAC_ADDR=$1
    HTTP_RESPONSE=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d '{"mac_addr": "'${MAC_ADDR}'"}' http://13.250.103.69:5000/getBackupExist)
    echo $HTTP_RESPONSE
}

# Function to calculate sleep time until 2 AM
calculate_sleep_time() {
    SLEEP_TIME=$(python3 -c "
    import pytz
    from datetime import datetime, timedelta

    # Specify Singapore time zone
    time_zone = pytz.timezone('Asia/Singapore')

    # Get the current time in the specified time zone
    now = datetime.now(time_zone)

    # Check if the current time is past 2 AM
    if now.hour > 2 or (now.hour == 2 and now.minute > 0):
        # Calculate time until 2 AM next day
        next_2_am = (now + timedelta(days=1)).replace(hour=2, minute=0, second=0, microsecond=0, tzinfo=None)
    else:
        # Calculate time until 2 AM today
        next_2_am = now.replace(hour=2, minute=0, second=0, microsecond=0, tzinfo=None)

    # Make next_2_am aware of the timezone
    next_2_am = time_zone.localize(next_2_am)

    # Calculate the difference in seconds
    delta = (next_2_am - now).total_seconds()

    print(int(delta))
    ")
    echo $SLEEP_TIME
}

# Function to sleep for the given amount of time
sleep_until_next_backup() {
    local SLEEP_TIME=$1
    echo "Waiting for $SLEEP_TIME seconds until the next 2 AM."
    sleep $SLEEP_TIME
}

# Function to create a backup via Supervisor API
create_backup() {
    local PAYLOAD='{"name": "'"$FILENAME"'"}'
    local BACKUP_ID=$(curl -s -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" -d "${PAYLOAD}" http://supervisor/backups/new/full | jq -r '.data.slug')
    echo $BACKUP_ID
}

# Function to download the backup
download_backup() {
    local BACKUP_ID=$1
    local BACKUP_PATH=$2
    curl -s -L -o "${BACKUP_PATH}" -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" "${BACKUP_API}/${BACKUP_ID}/download"
    echo "Backup downloaded successfully to ${BACKUP_PATH}"
}

# Function to compare two json files
compare_json_files() {
    local DIFF=true
    local OLD_BACKUP_VERSION_JSON_PATH=$1
    local BACKUP_PATH=$2
    local HTTP_RESPONSE=$3
    local RESPONSE_BODY=$4
    if [ "$HTTP_RESPONSE" -eq 200 ]; then
        echo $RESPONSE_BODY  > $OLD_BACKUP_VERSION_JSON_PATH
        DIFF=$(./compare.sh $BACKUP_PATH $OLD_BACKUP_VERSION_JSON_PATH)
    fi
    echo $DIFF
}

# Function to upload backup and version json files to S3
upload_backup_files() {
    local BACKUP_PATH=$1
    local MAC_ADDR=$2
    local VERSION_JSON_FILE="./backup.json"
    tar -xf $BACKUP_PATH $VERSION_JSON_FILE
    RESPONSE=$(curl -X POST -F file=@"${VERSION_JSON_FILE}" -F "mac_addr=\"${MAC_ADDR}\"" http://13.250.103.69:5000/uploadBackupVersion)
    rm $VERSION_JSON_FILE

    RESPONSE=$(curl -X POST -F file=@"${BACKUP_PATH}" -F "mac_addr=\"${MAC_ADDR}\"" http://13.250.103.69:5000/uploadBackupFile)
    echo "s3 response: $RESPONSE"
}

# Function to store backup information in json file
store_backup_info() {
    local FILENAME=${FILENAME}.tar
    local size=$(du /tmp/${FILENAME} |  awk '{print $1/1000}')
    local sleep_start=$(date +%s)
    local sleep_end=$(python -c "from datetime import datetime, timedelta; print(int((datetime.now() + timedelta(days=10)).timestamp()))")
    local JSON_FILE="/tmp/backup_info.json"
    echo "{\"mac_addr\": \"$MAC_ADDR\", \"filename\": \"$FILENAME\", \"size\": $size, \"sleep_start\": $sleep_start, \"sleep_end\": $sleep_end}" > $JSON_FILE
    RESPONSE=$(curl -X POST -H "Content-Type: application/json" -d @"${JSON_FILE}" http://13.250.103.69:5000/uploadBackupDetails)
    rm $JSON_FILE
}

# Function to upload 3 files:
#   1. backup_restored.tar: the backup file
#   2. backup_version.json: a json file used to determine if a new backup is different enough from the one in the cloud
#   3. backup_details.json: a json file containing mac_addr, filename, size, sleep_start and sleep_end
initiate_backup() {
    local MAC_ADDR=$1
    # Create a new backup via Supervisor API
    BACKUP_ID=$(create_backup)

    # Check if the snapshot ID was obtained
    if [ "${BACKUP_ID}" == "null" ] || [ -z "${BACKUP_ID}" ];
    then
        echo "Failed to create backup."
    else
        echo "Backup created successfully. Snapshot ID: ${BACKUP_ID}"

        # Download the backup from HA
        download_backup "$BACKUP_ID" "$BACKUP_PATH"

        # Fetch the old backup version json file from S3 (check version cache first)
        HTTP_RESPONSE=$(curl -s -o response.txt -w "%{http_code}" -X POST -H "Content-Type: application/json" -d '{"mac_addr": "'${MAC_ADDR}'"}' http://13.250.103.69:5000/getBackupVersion)
        RESPONSE_BODY=$(cat response.txt)
        
        # compare the json files if exists
        DIFF=$(compare_json_files "$OLD_BACKUP_VERSION_JSON_PATH" "$BACKUP_PATH" "$HTTP_RESPONSE" "$RESPONSE_BODY")        
        BACKUP_HTTP_RESPONSE=$(check_backup_exists "$MAC_ADDR")

        # If true, upload and update the json in s3 (update version cache) , else, dont upload
        if [ "$DIFF" = true ] || [ "$BACKUP_HTTP_RESPONSE" -ne 200 ]; then
            upload_backup_files "$BACKUP_PATH" "$MAC_ADDR"
        else
            echo "Backup is the same, no backup is uploaded to the cloud"
        fi
        
        # update backup details to ensure that the addon page displays the latest details
        store_backup_info
    fi
}

#####################
# Start of execution
#####################

# Get the mac address and store it in tmp txt file
MAC_ADDR=$(get_mac_address)
save_mac_address "$MAC_ADDR"

# Check if backup exists in the cloud
HTTP_RESPONSE=$(check_backup_exists "$MAC_ADDR")
if [ "$HTTP_RESPONSE" -ne 200 ]; then
    initiate_backup "$MAC_ADDR"     # start backup if it doesn't exist
fi

# Sleep until the following 2am (chosen to avoid peak time)
SLEEP_TIME=$(calculate_sleep_time)
sleep_until_next_backup "$SLEEP_TIME"

# Initiate backup every 10 days
while true; do
    initiate_backup "$MAC_ADDR"
    sleep 864000  # Sleeps for 10 days
done

##################
# End of execution
##################