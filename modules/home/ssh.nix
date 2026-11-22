{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        User = "git";
      };
      "*.lion-zebra.ts.net" = {
        PubkeyAuthentication = "unbound";
        # Since encryption can't be disabled on newer OpenSSH versions, we'll settle for
        # the most lightweight encryption. Tailscale already encrypts everything so this
        # another layer of encryption can be avoided.
        Ciphers = "chacha20-poly1305@openssh.com,aes128-gcm@openssh.com";
        # ConnectTimeout = "3";
      };
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = true;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    };
  };
  # services.ssh-agent = {
  #   enable = true;
  # };
}
