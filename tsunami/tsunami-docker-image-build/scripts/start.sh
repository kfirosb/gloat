#!/bin/bash

# Read the list of IP addresses from a file (one IP per line)
IP_FILE="/mnt/tsunami-data/ip_list.txt"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

while IFS= read -r IP; do
  if [[ -n "$IP" ]]; then
    # Run the Java command with the specified IP
    mkdir /mnt/logs
    OUTPUT_FILE="tsunami-output-${IP}-${TIMESTAMP}.json"
    java -cp "tsunami.jar:plugins/*" -Dtsunami-config.location=tsunami.yaml com.google.tsunami.main.cli.TsunamiCli \
        --ip-v4-target="$IP" --scan-results-local-output-format=JSON --scan-results-local-output-filename="/mnt/logs/$OUTPUT_FILE"
    
    # Print the completion message
    sed -e 's/^ *//' < /mnt/logs/$OUTPUT_FILE | tr -d '\n' > /mnt/tsunami-logs/$OUTPUT_FILE 
    
    echo "Tsunami scan for $IP completed. Output saved to $OUTPUT_FILE"
  fi
done < "$IP_FILE"
