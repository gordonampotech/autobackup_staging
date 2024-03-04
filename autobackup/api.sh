#!/bin/bash
# Define Supervisor API URL
BACKUP_API="http://supervisor/backups"
FILE_PATH="/backup/mac_addr.txt"

while true; do
    # Prints the time when the backup is being made
    date

    # Get Mac Address from eth0
    MAC_ADDR=$(ip link show eth0 | awk '/ether/ {print $2}')
    MAC_ADDR=$(echo $MAC_ADDR | tr -d ':')

    # Use the variable as needed
    echo "The mac address is: $MAC_ADDR"
    echo $MAC_ADDR > /tmp/mac_address.txt

    # Generate a UUID as the backup filename
    FILENAME="backup_restored"
    echo $FILENAME

    # JSON payload to create a new full backup
    PAYLOAD='{"name": "'"$FILENAME"'"}'

    # Create a new backup via Supervisor API
    BACKUP_ID=$(curl -s -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json" -d "${PAYLOAD}" http://supervisor/backups/new/full | jq -r '.data.slug')

    # Check if the snapshot ID was obtained
    if [ "${BACKUP_ID}" == "null" ] || [ -z "${BACKUP_ID}" ];
    then
        echo "Failed to create backup."
    else
        echo "Backup created successfully. Snapshot ID: ${BACKUP_ID}"
        # Define path where to save the backup file
        BACKUP_PATH="/tmp/${FILENAME}.tar"

        # Download the backup
        curl -s -L -o "${BACKUP_PATH}" -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" "${BACKUP_API}/${BACKUP_ID}/download"

        echo "Backup downloaded successfully to ${BACKUP_PATH}"

        # Get file name
        filename=${FILENAME}.tar
        # Get file size
        size=$(du /tmp/${filename} |  awk '{print $1/1000}')
        # Get current timestamp
        sleep_start=$(date +%s)
        # Get timestamp 10 days later
        sleep_end=$(python -c "from datetime import datetime, timedelta; print(int((datetime.now() + timedelta(days=10)).timestamp()))")

        # Store file info in json
        json_file="/tmp/backup_info.json"
        echo "{\"mac_addr\": \"$MAC_ADDR\", \"filename\": \"$filename\", \"size\": $size, \"sleep_start\": $sleep_start, \"sleep_end\": $sleep_end}" > $json_file
        cat $json_file

        RESPONSE=$(curl -X POST -H "Content-Type: application/json" -d @"${json_file}" http://13.250.103.69:5000/uploadBackupDetails)
        RESPONSE=$(curl -X POST -F file=@"${BACKUP_PATH}" -F "mac_addr=\"${MAC_ADDR}\"" http://13.250.103.69:5000/uploadBackupFile)
        echo "s3 response: $RESPONSE"
    fi
    
    sleep 864000  # Sleeps for 10 days
done
