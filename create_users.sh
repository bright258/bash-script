#!/bin/bash

# Check if the script is run as root, if not re-execute it with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Re-executing with sudo..."
    sudo bash "$0" "$@"
    exit $?
fi


# Define paths to log and password file 
LOGGER="var/log/user_management.log"
PASSWORD_FILE="var/secure/user_passwords.txt"


# Ensure directories and files exist with necessary permissions
sudo mkdir -p var/log
sudo mkdir -p var/secure
sudo chmod 700 /var/secure
sudo touch $LOGGER
sudo chmod 600 /var/secure/user_passwords.txt
sudo chown root:root /var/secure/user_passwords.txt
sudo touch $PASSWORD_FILE

# Function for generating logs
logging_function(){
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> $LOGGER
}

# Function for generating random passwords
password_generator(){
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Check if a user text file was provided
if [ -z "$1" ];then 
  echo "Usage: $0 <user_file>"
  exit 1
fi

# Read the file line by line and loop through
while IFS=';' read -r user groups || [ -n "$user" ]; do
  # Trimming whitespace
  user=$(echo "$user" | xargs)
  groups=$(echo "$groups" | xargs)
  
  # Skip empty lines
  [ -z "$user" ] && continue
   
  # Check if user already exists
  if id "$user" &>/dev/null;  then
    logging_function "User $user already exists."
    continue
  fi
  
  # Create user and generate password
  password=$(password_generator)
  sudo useradd -m -s /bin/bash "$user"
    if [ $? -ne 0 ]; then
        log_action "Failed to create user $user"
        continue
    fi
  echo "$user:password" | chpasswd

  logging_function "User $user created with home directory"
   
  # Create personal group and assign to user
  sudo usermod -aG "$user" "$user"

  # Assign additional groups to user
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo $group | xargs)
    if [ -n "$group" ]; then
        if ! getent group "$group" > /dev/null 2>&1; then
            groupadd "$group"
            logging_function "Group $group created"
        fi
        usermod -aG "$group" "$user"
        logging_function "User $user added to group $group"
    fi
    done
    
    # Set home directory permissions
    sudo chmod 700 /home/$user
    sudo chown $user:$user /home/$user
    
    # Store password securely
    echo "$user, $password" >> $PASSWORD_FILE
    logging_function "password for $user stored"
done < "$1"

#Give a success response
echo "User creation complete. Check $LOGGER"







