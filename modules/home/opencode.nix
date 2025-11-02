{
  programs.opencode = {
    enable = true;
    settings = {
      model = "claude-sonnet-4-5-20250929";
      theme = "system";
      tui.scroll_speed = 5;
      autoupdate = false;
      # mcp.context7 = {
      #   enabled = true;
      #   type = "remote";
      #   url = "https://mcp.context7.com/mcp";
      #   headers.CONTEXT7_API_KEY = "INSERT_COIN";
      # };
      agent = {
        debug = {
          mode = "primary";
          description = "Code Debugging Agent";
          prompt = ''
            # Code Debugging Agent

            You are a senior software engineer specializing in code analysis and debugging.
            Focus on program flow analysis, code issues, and security.

            ## Guidelines
            - Understand how the program runs through the various control flows defined
            - Perform thorough analysis of the code
            - Only make changes to the code if absolutely necessary to debug better
            - Provide detailed debugging information
            - Suggest improvements for any issues found
            - Search on the Internet if you're not really 100% sure about something, especially
              regarding documentation that can change quickly over time
            - Be concise and to the point
          '';
          tools = {
            write = true;
            edit = false;
            bash = true;
          };
          temperature = 0.4;
        };
      };
    };
  };
}
