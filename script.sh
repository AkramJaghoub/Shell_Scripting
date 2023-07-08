#!/bin/bash

EXTENSION=""
DIR=""
REPORT_FILE="file_analysis.txt"

function display_help() {
  echo ""
  echo "Usage: ./script.sh DIRECTORY_PATH [OPTIONS]"
  echo "Options:"
  echo "  -e, --extensions   Filter files by extensions (comma-separated)"
  echo "  -h, --help         Display help information"
  echo ""
}

function validate_directory() {
  while true
  do
    if [ -z "$DIR" ]; then
      echo ""
      echo "Missing directory argument. Please enter a directory!"
      
    elif ! [ -d "$DIR" ]; then
      echo "$DIR is not a valid directory. Please enter a valid directory!"
    else
      break
    fi
    read -p "Enter a directory: " DIR
  done
}

function validate_extension() {
  while true
  do
    if [ -z "$EXTENSION" ]; then
      echo ""
      echo "Missing file extension argument. Please enter a file extension!"
   
    elif ! [[ $EXTENSION =~ ^\.[a-zA-Z0-9]+$ ]]; then
      echo "Invalid file extension format. Please enter a valid file extension starting with a dot (e.g., .txt, .jpeg, .sh)."
      
    else
      break
    fi
    read -p "Enter a file extension: " EXTENSION
  done
}

function generate_report() {
  echo ""
  echo "Generating report................."

  echo "" > "$REPORT_FILE"
  echo "----------- $(echo "$FILES" | wc -l) Files found -----------" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"

  declare -A files_by_owner
  declare -A owner_sizes

  while read FILE
  do
    FILENAME=$(basename "$FILE")
    FILE_INFO=($(stat -c "%s %A %U %y" "$FILE"))

    files_by_owner["${FILE_INFO[2]}"]+="${FILE_INFO[0]} $FILENAME ${FILE_INFO[1]} ${FILE_INFO[2]} ${FILE_INFO[3]}"$'\n'
    owner_sizes["${FILE_INFO[2]}"]=$((owner_sizes["${FILE_INFO[2]}"] + ${FILE_INFO[0]}))
  done <<< "$FILES"

  sorted_owners=$(for OWNER in "${!owner_sizes[@]}"; do echo "${owner_sizes[$OWNER]} $OWNER"; done | sort -rn | cut -d ' ' -f 2)

  for OWNER in $sorted_owners
  do
    OWNER_SIZE=${owner_sizes["$OWNER"]}

    echo "Owner: $OWNER" >> "$REPORT_FILE"
    echo "Total Size: $OWNER_SIZE bytes" >> "$REPORT_FILE"
    echo "----------------------------" >> "$REPORT_FILE"

    sorted_files=$(echo "${files_by_owner["$OWNER"]}" | sort -k1,1rn)

    while read line
    do
      read SIZE FILENAME PERMISSIONS OWNER LAST_MODIFIED <<< "$line"

      echo "File Name: $FILENAME" >> "$REPORT_FILE"
      echo "File permissions: $PERMISSIONS" >> "$REPORT_FILE"
      echo "File owner: $OWNER" >> "$REPORT_FILE"
      echo "File size(bytes): $SIZE" >> "$REPORT_FILE"
      echo "Last modification done on the file: $LAST_MODIFIED" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    done <<< "$sorted_files"

    echo "" >> "$REPORT_FILE"	
  done

  echo "Report generated successfully. Please check $REPORT_FILE for the file analysis."
}

while [ $# -gt 0 ] 
do
  case $1 in
    -e|--extensions)
      EXTENSION="$2" 
      shift 2
      ;;
    -h|--help)
      display_help
      exit 0
      ;;
    *)
      DIR="$1"
      shift
      ;;
  esac
done

validate_directory
validate_extension

# Search for files with the given extension in the directory
FILES=$(find "$DIR" -type f -name "*$EXTENSION")

if [ -z "$FILES" ]; then
  echo "No files found with the extension '$EXTENSION' in the directory '$DIR'."
  exit 4
fi

generate_report
