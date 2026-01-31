{ pkgs, inputs, config, ... }:
{
  sops.secrets."paperless-ngx-push.env" = {};

  home.packages = with pkgs; [
    (writeShellScriptBin "paperless-ngx-push" ''
      # Initialize variables
      FILES=()
      TAGS=()

      # Parse command line arguments
      while [[ $# -gt 0 ]]; do
        case $1 in
          --tags|-t)
            shift
            # Split comma-separated tags
            IFS=',' read -ra TAG_ARRAY <<< "$1"
            for tag in "''${TAG_ARRAY[@]}"; do
              # Trim whitespace
              TAGS+=("''${tag// /}")
            done
            shift
            ;;
          --help|-h)
            ${pkgs.coreutils}/bin/echo "Usage: $0 [--tags|-t tag1,tag2,tag3] <file_to_upload> [<file_to_upload> ...]"
            ${pkgs.coreutils}/bin/echo "  --tags, -t    Comma-separated list of tags to apply to uploaded documents"
            ${pkgs.coreutils}/bin/echo "  --help, -h     Show this help message"
            exit 0
            ;;
          -*)
            ${pkgs.coreutils}/bin/echo "Error: Unknown option $1"
            ${pkgs.coreutils}/bin/echo "Use --help for usage information"
            exit 1
            ;;
          *)
            FILES+=("$1")
            shift
            ;;
        esac
      done

      # Check if at least one file argument is provided
      if [ ''${#FILES[@]} -lt 1 ]; then
        ${pkgs.coreutils}/bin/echo "Error: No files specified"
        ${pkgs.coreutils}/bin/echo "Usage: $0 [--tags|-t tag1,tag2,tag3] <file_to_upload> [<file_to_upload> ...]"
        exit 1
      fi

      # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
      # to work:
      # source $\{osConfig.sops.secrets."paperless-ngx-push.env".path}
      source ${config.sops.secrets."paperless-ngx-push.env".path}

      # Function to convert tag names to tag IDs
      get_tag_ids() {
        local tag_names=("$@")
        local tag_ids=()

        # Get all tags from API
        TAGS_JSON=$(${pkgs.curl}/bin/curl -s -H "Authorization: Token $PAPERLESS_NGX_API_KEY" "$PAPERLESS_NGX_INSTANCE_URL/api/tags/")

        for tag_name in "''${tag_names[@]}"; do
          # Extract tag ID for the given tag name
          TAG_ID=$(echo "$TAGS_JSON" | ${pkgs.jq}/bin/jq -r --arg tag_name "$tag_name" '.results[] | select(.name == $tag_name) | .id')

          if [ "$TAG_ID" != "null" ] && [ -n "$TAG_ID" ]; then
            tag_ids+=("$TAG_ID")
          else
            ${pkgs.coreutils}/bin/echo "Warning: Tag '$tag_name' not found. It will be created if allowed."
            # For now, skip unknown tags
            # In the future, we could create them here
          fi
        done

        # Return the tag IDs as space-separated string
        echo "''${tag_ids[@]}"
      }

      # Convert tag names to IDs if tags are provided
      TAG_IDS=""
      if [ ''${#TAGS[@]} -gt 0 ]; then
        TAG_IDS=$(get_tag_ids "''${TAGS[@]}")
      fi

      # Loop through all provided files
      for FILE in "''${FILES[@]}"; do
        # Check if the file exists and is a regular file
        if [ ! -f "$FILE" ]; then
          ${pkgs.coreutils}/bin/echo "Error: $FILE does not exist or is not a valid file."
          continue
        fi

        # Upload the file with tags
        ${pkgs.coreutils}/bin/echo "Uploading $FILE..."
        if [ ''${#TAGS[@]} -gt 0 ]; then
          ${pkgs.coreutils}/bin/echo "Applying tags: ''${TAGS[*]}"
        fi

        # Handle filenames with special characters by using a temp file
        TEMP_FILE=$(${pkgs.coreutils}/bin/mktemp -u)
        ${pkgs.coreutils}/bin/cp "$FILE" "$TEMP_FILE"

        # Build curl command using temp file
        CURL_CMD="${pkgs.curl}/bin/curl -s -H \"Authorization: Token $PAPERLESS_NGX_API_KEY\" -F \"document=@$TEMP_FILE\""

        # Add tag IDs if provided
        for tag_id in $TAG_IDS; do
          CURL_CMD="$CURL_CMD -F \"tags=$tag_id\""
        done

        CURL_CMD="$CURL_CMD \"$PAPERLESS_NGX_INSTANCE_URL/api/documents/post_document/\""

        # Debug: print what curl will execute
        ${pkgs.coreutils}/bin/echo "DEBUG: $CURL_CMD" >&2

        # Execute curl command
        eval "$CURL_CMD"
        curl_exit_code=$?

        # Clean up temp file
        ${pkgs.coreutils}/bin/rm -f "$TEMP_FILE"

        if [ $curl_exit_code -eq 0 ]; then
          ${pkgs.coreutils}/bin/echo "$FILE uploaded successfully."
        else
          ${pkgs.coreutils}/bin/echo "Failed to upload $FILE."
          exit $curl_exit_code
        fi
      done

      ${pkgs.coreutils}/bin/echo "File upload process complete."
    '')
  ];
}
