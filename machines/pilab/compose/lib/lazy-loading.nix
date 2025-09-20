# Shared module for lazy-loading service status pages
{ pkgs, lib, ... }:

{
  # Generate a connection handler script for lazy-loading services
  mkLazyLoadingHandler = { serviceName, dockerServiceName, internalPort, refreshInterval ? 3 }: 
    pkgs.writeShellScript "${serviceName}-connection-handler" ''
      echo "Connection received at $(date)" >&2

      # Check if service container is running first
      if ! ${pkgs.systemd}/bin/systemctl is-active --quiet docker-${dockerServiceName}.service; then
        echo "Starting ${serviceName} container..." >&2
        ${pkgs.systemd}/bin/systemctl start docker-${dockerServiceName}.service

        # Send loading page immediately
        cat << 'EOF'
      HTTP/1.1 200 OK
      Content-Type: text/html
      Connection: close

      <!DOCTYPE html>
      <html>
      <head>
          <title>${serviceName} - Starting</title>
          <meta http-equiv="refresh" content="${toString refreshInterval}">
          <style>
              body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
              .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 2s linear infinite; margin: 20px auto; }
              @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
          </style>
      </head>
      <body>
          <h1>${serviceName} is starting...</h1>
          <div class="spinner"></div>
          <p>Please wait while the service loads. This page will refresh automatically.</p>
          <p><a href="/">Click here to refresh manually</a></p>
      </body>
      </html>
      EOF
        exit 0
      fi

      # Service is already running, check if it's responding
      if ${pkgs.curl}/bin/curl -s --connect-timeout 2 http://127.0.0.1:${toString internalPort}/ >/dev/null 2>&1; then
        echo "${serviceName} is ready, proxying connection..." >&2
        # Forward the entire HTTP connection to the actual service
        exec ${pkgs.socat}/bin/socat - TCP:127.0.0.1:${toString internalPort}
      else
        echo "${serviceName} not responding, sending loading page..." >&2
        # Send loading page
        cat << 'EOF'
      HTTP/1.1 200 OK
      Content-Type: text/html
      Connection: close

      <!DOCTYPE html>
      <html>
      <head>
          <title>${serviceName} - Starting</title>
          <meta http-equiv="refresh" content="2">
          <style>
              body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
              .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #3498db; border-radius: 50%; width: 40px; height: 40px; animation: spin 2s linear infinite; margin: 20px auto; }
              @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
          </style>
      </head>
      <body>
          <h1>${serviceName} is starting...</h1>
          <div class="spinner"></div>
          <p>Service is warming up. This page will refresh automatically.</p>
      </body>
      </html>
      EOF
      fi
    '';

  # Generate an error page for services that fail to start  
  mkErrorPage = { serviceName }:
    ''
      HTTP/1.1 503 Service Unavailable
      Content-Type: text/html
      Connection: close

      <!DOCTYPE html>
      <html>
      <head>
          <title>${serviceName} - Service Starting</title>
          <style>
              body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
              .error { color: #e74c3c; }
          </style>
      </head>
      <body>
          <h1 class="error">${serviceName} is starting...</h1>
          <p>Please wait a moment and refresh the page.</p>
          <p><a href="/">Click here to refresh</a></p>
      </body>
      </html>
    '';
}