{ pkgs, config }:
pkgs.writeShellScriptBin "paperless-ngx-push" ''
  FILES=()
  TAGS=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --tags|-t)
        shift
        IFS=',' read -ra TAG_ARRAY <<< "$1"
        for tag in "''${TAG_ARRAY[@]}"; do
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

  if [ ''${#FILES[@]} -lt 1 ]; then
    ${pkgs.coreutils}/bin/echo "Error: No files specified"
    ${pkgs.coreutils}/bin/echo "Usage: $0 [--tags|-t tag1,tag2,tag3] <file_to_upload> [<file_to_upload> ...]"
    exit 1
  fi

  source ${config.sops.secrets."paperless-ngx-push.env".path}

  get_tag_ids() {
    local tag_names=("$@")
    local tag_ids=()

    TAGS_JSON=$(${pkgs.curl}/bin/curl -s -H "Authorization: Token $PAPERLESS_NGX_API_KEY" "$PAPERLESS_NGX_INSTANCE_URL/api/tags/")

    for tag_name in "''${tag_names[@]}"; do
      TAG_ID=$(echo "$TAGS_JSON" | ${pkgs.jq}/bin/jq -r --arg tag_name "$tag_name" '.results[] | select(.name == $tag_name) | .id')

      if [ "$TAG_ID" != "null" ] && [ -n "$TAG_ID" ]; then
        tag_ids+=("$TAG_ID")
      else
        ${pkgs.coreutils}/bin/echo "Warning: Tag '$tag_name' not found. It will be created if allowed."
      fi
    done

    echo "''${tag_ids[@]}"
  }

  TAG_IDS=""
  if [ ''${#TAGS[@]} -gt 0 ]; then
    TAG_IDS=$(get_tag_ids "''${TAGS[@]}")
  fi

  for FILE in "''${FILES[@]}"; do
    if [ ! -f "$FILE" ]; then
      ${pkgs.coreutils}/bin/echo "Error: $FILE does not exist or is not a valid file."
      continue
    fi

    ${pkgs.coreutils}/bin/echo "Uploading $FILE..."
    if [ ''${#TAGS[@]} -gt 0 ]; then
      ${pkgs.coreutils}/bin/echo "Applying tags: ''${TAGS[*]}"
    fi

    ORIGINAL_NAME=$(${pkgs.coreutils}/bin/basename "$FILE")

    TEMP_DIR=$(${pkgs.coreutils}/bin/mktemp -d)
    ${pkgs.coreutils}/bin/ln -s "$(${pkgs.coreutils}/bin/realpath "$FILE")" "$TEMP_DIR/upload"

    CURL_ARGS=(
      -s
      -H "Authorization: Token $PAPERLESS_NGX_API_KEY"
      -F "document=@$TEMP_DIR/upload;filename=\"$ORIGINAL_NAME\""
    )

    for tag_id in $TAG_IDS; do
      CURL_ARGS+=(-F "tags=$tag_id")
    done

    CURL_ARGS+=("$PAPERLESS_NGX_INSTANCE_URL/api/documents/post_document/")

    ${pkgs.curl}/bin/curl "''${CURL_ARGS[@]}"
    curl_exit_code=$?

    ${pkgs.coreutils}/bin/rm -rf "$TEMP_DIR"

    if [ $curl_exit_code -eq 0 ]; then
      ${pkgs.coreutils}/bin/echo "$FILE uploaded successfully."
    else
      ${pkgs.coreutils}/bin/echo "Failed to upload $FILE."
      exit $curl_exit_code
    fi
  done

  ${pkgs.coreutils}/bin/echo "File upload process complete."
''
