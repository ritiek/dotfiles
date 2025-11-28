{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        user = "git";
      };
      "*.lion-zebra.ts.net" = {
        extraOptions = {
          PubkeyAuthentication = "unbound";
          # Since encryption can't be disabled on newer OpenSSH versions, we'll settle for
          # the most lightweight encryption. Tailscale already encrypts everything so this
          # another layer of encryption can be avoided.
          Ciphers = "chacha20-poly1305@openssh.com,aes128-gcm@openssh.com";
        };
      };
      "*" = {
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = true;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };
  };
  services.ssh-agent = {
    enable = true;
  };
}
