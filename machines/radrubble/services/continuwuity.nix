{ ... }:

{
  # Moved from pilab. server_name stays pilab's: it is baked into every user
  # and room ID, so changing it would orphan the existing database. Clients
  # connect to radrubble:6168 instead.
  services.matrix-continuwuity = {
    enable = true;
    admin.enable = true;
    settings.global = {
      server_name = "pilab.lion-zebra.ts.net";
      port = [ 6168 ];
      address = [ "0.0.0.0" "::" ];
      allow_registration = false;
      yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse = false;
      unix_socket_perms = 660;
      allow_federation = false;
      allow_encryption = true;
      trusted_servers = [ ];
      max_request_size = 20000000;
    };
  };

  networking.firewall.allowedTCPPorts = [ 6168 ];
}
