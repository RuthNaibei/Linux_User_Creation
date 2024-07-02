#!/bin/bash

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Check if input file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi

INPUT_FILE="$1"

# Create necessary directories
mkdir -p /var/log
mkdir -p /var/secure

# Initialize log and password files
echo "User Management Log" > $LOG_FILE
echo "username,password" > $PASSWORD_FILE

# Function to generate a random password
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Process each line in the input file
while IFS=';' read -r username groups; do
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)
  
  if id "$username" &>/dev/null; then
    echo "User $username already exists." >> $LOG_FILE
  else
    # Create user's primary group
    groupadd "$username"

    # Create user and add to the primary group
    useradd -m -s /bin/bash -g "$username" "$username"
    echo "Created user $username." >> $LOG_FILE

    # Setting permissions
    chmod 700 /home/$username
    chown $username:$username /home/$username
    echo "Set home directory permissions for $username." >> $LOG_FILE

    # Generating and setting the password
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username,$password" >> $PASSWORD_FILE
    echo "Password set for user $username." >> $LOG_FILE
  fi

  # Add user to additional groups
  IFS=',' read -r -a group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs)
    if [ ! -z "$group" ]; then
      if ! getent group "$group" > /dev/null; then
        groupadd "$group"
        echo "Created group $group." >> $LOG_FILE
      fi
      usermod -aG "$group" "$username"
      echo "Added $username to group $group." >> $LOG_FILE
    fi
  done
done < "$INPUT_FILE"

# Setting permissions for password files
chmod 600 $PASSWORD_FILE
chown root:root $PASSWORD_FILE
echo "Password file permission set." >> $LOG_FILE
echo "User creation process completed." >> $LOG_FILE

exit 0
