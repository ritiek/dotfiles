# Built ahead of time: under `npx -y` the first start downloads the package,
# which on the Pi outlasts Bifrost's fixed MCP connection timeout.
{ buildNpmPackage, fetchFromGitHub }:

buildNpmPackage rec {
  pname = "paperless-mcp";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "baruchiro";
    repo = "paperless-mcp";
    tag = "v${version}";
    hash = "sha256-yijRjk6/CSzuBU2VRwPz7swQiu4+Kzd1oTU8gujpc28=";
  };

  npmDepsHash = "sha256-ek8p3FmcM24RdpFXEAbJ4RFJDcA8j9bpmNfPXF3wGjc=";

  # prepack also builds a Claude Desktop extension, which needs a network fetch.
  npmPackFlags = [ "--ignore-scripts" ];

  meta.mainProgram = "paperless-mcp";
}
