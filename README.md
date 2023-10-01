# Tsunami Network Scan and Notify

This repository contains two services: Tsunami and Fluent-Bit. Our goal is to perform network scans using the Tsunami network scanner and notify relevant parties via Fluent-Bit and Slack whenever vulnerabilities are detected.

## Overview

Here's how the process works:

1. We deploy Tsunami to a Kubernetes cluster using a Helm chart. This deployment includes a cron job that scans a list of services specified in `tsunami/data/ip_list.txt`. This list is mounted as a volume to the cron job. The cron job runs according to a schedule and places scan report files in the mounted folder, which is also shared with Fluent-Bit.

2. Fluent-Bit monitors the shared folder for new scan reports. When a new report is detected, it checks for the presence of scan findings and vulnerabilities. If vulnerabilities are found, Fluent-Bit sends a Slack message containing the server IP and vulnerability details. It also stores the results in a backup file.

## Dependencies

Before proceeding, ensure you have the following dependencies in place:

- Kubernetes cluster
- Helm
- Docker (for building Tsunami Docker image)
- Image registry
- kubectl

## Installation

### Clone the Repository

```bash
git clone git@github.com:kfirosb/gloat.git
cd gloat
```

### Deploy Fluent-Bit

1. Navigate to the `fluent-bit` directory.

2. Edit the file `fluent-bit-pv.yaml`. Modify the "path/for/output" and "path/for/logs" with your local paths.

3. Create volumes and volume claims by running the following command:
   ```bash
   kubectl apply -f fluent-bit-pv.yaml
   ```

4. Change the Slack URL in `values-fluent-bit.yaml` under the "output webhook" field. To create an incoming webhook in Slack, refer to the [Slack API documentation](https://api.slack.com/messaging/webhooks#getting_started).

5. Install Fluent-Bit using Helm:
   ```bash
   helm upgrade --install fluent-bit fluent/fluent-bit -f values-fluent-bit.yaml
   ```

### Deploy Tsunami

1. Navigate to the `tsunami/tsunami-docker-image-build` directory.

2. Build the Tsunami Docker image:
   ```bash
   docker build -t tsunami .
   ```

3. Tag and push the Tsunami image to your image registry.

4. Modify the Image Location in the Cron Job Configuration:
Open the tsunami-helm-chart/templates/tsunami-cronjob.yaml file and locate the image field. Replace the image location with the location where you pushed the Tsunami image in step 3.

5. Change the Scheduled Time in the Cron Job:
To run the Cron Job when you want, modify the Cron Job schedule. In the `tsunami-helm-chart/templates/tsunami-cronjob.yaml` file, locate the schedule field and set it to:

```yaml
schedule: "0 3 * * *"
```
This Cron Job expression represents "0 minutes past 6 AM every day at 6 AM Israel time."

6. In the file `tsunami/tsunami-helm-chart/templates/tsunami-data-pv.yaml`, update the path to the location where you plan to place the `ip_list.txt` file for server IP list configuration.

7. In the file `tsunami/tsunami-helm-chart/templates/tsunami-logs-pv.yaml`, update the path to match the mount location for the Fluent-Bit logs configured in step 3 of the Fluent-Bit deployment.

8. Navigate to the `tsunami` directory.

8. Create a Tsunami namespace:
   ```bash
   kubectl create ns tsunami
   ```

9. Install Tsunami using Helm:
   ```bash
   helm upgrade --install -n tsunami tsunami-scanner ./tsunami-helm-chart
   ```

## Process Explanation

### Tsunami

Tsunami includes a script located at `tsunami/tsunami-docker-image-build/scripts/start.sh`. This script reads the server IP list file and runs Tsunami scans for each IP address. It takes the JSON Tsunami report, condenses it into a one-liner, and renames it with the server IP and timestamp.

```bash
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
```

### Fluent-Bit

Fluent-Bit employs a Lua script as a filter to process records. The script searches for the presence of scanFindings and vulnerabilities in each record. If vulnerabilities are found, the script passes the relevant information to Slack for notification.

```lua
function process_record(tag, timestamp, record)
    local scanFindings = record["scanFindings"]
    if not scanFindings or #scanFindings == 0 then
        return -1 -- Skip records without scanFindings
    end

    local address = scanFindings[1]["targetInfo"]["networkEndpoints"][1]["ipAddress"]["address"]
    record = {}  -- Clear the record
    record["ipAddress"] = address

    -- Check if vulnerability exists in scanFindings
    local vulnerability = scanFindings[1]["vulnerability"]
    if vulnerability then
        record["vulnerability"] = vulnerability
    end

    return 1, timestamp, record
end
```

With this setup, you can effectively scan your network for vulnerabilities and receive timely notifications through Slack whenever vulnerabilities are detected.