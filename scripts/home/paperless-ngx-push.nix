{ pkgs, inputs, config, ... }:
{
  sops.secrets."paperless-ngx-push.env" = {};

  home.packages = with pkgs; [
    (writeShellScriptBin "paperless-ngx-push" ''
      # Check if at least one file argument is provided
      if [ $# -lt 1 ]; then
        ${pkgs.coreutils}/bin/echo "Usage: $0 <file_to_upload> [<file_to_upload> ...]"
        exit 1
      fi

      # TODO: Shouldn't have to hardcode the path here. But I couldn't get the following
      # to work:
      # source $\{osConfig.sops.secrets."paperless-ngx-push.env".path}
      source ~/.config/sops-nix/secrets/paperless-ngx-push.env

      # Loop through all provided files
      for FILE in "$@"; do
        # Check if the file exists and is a regular file
        if [ ! -f "$FILE" ]; then
          ${pkgs.coreutils}/bin/echo "Error: $FILE does not exist or is not a valid file."
          continue
        fi

        # Upload the file
        ${pkgs.coreutils}/bin/echo "Uploading $FILE..."

        ${pkgs.curl}/bin/curl -s -H "Authorization: Token $PAPERLESS_NGX_API_KEY" -F "document=@$FILE" "$PAPERLESS_NGX_INSTANCE_URL/api/documents/post_document/"

        if [ $? -eq 0 ]; then
          ${pkgs.coreutils}/bin/echo "$FILE uploaded successfully."
        else
          ${pkgs.coreutils}/bin/echo "Failed to upload $FILE."
          exit $?
        fi
      done

      ${pkgs.coreutils}/bin/echo "File upload process complete."
    '')
  ];
}
