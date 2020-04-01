This crappy lapbook is a prime example of how much pain in the ass 64-bit CPUs
with 32-bit UEFI can be.

This thing comes with a pre-installed Windows 10 (which worked pretty decent btw).

But removing this pre-installed Windows and installing any other major OS
is going to make you lose your sanity (even re-installing Windows 10!).

It took a me a week just to get a 64-bit Linux (Mint) running on the damn thing
enough to be usable.

This reference was pretty helpful:
https://medium.com/@realzedgoat/a-sorta-beginners-guide-to-installing-ubuntu-linux-on-32-bit-uefi-machines-d39b1d1961ec

Now comes the plethora of hardware issues:

- Touchpad gets detected as a mouse instead of a touchpad. That means no 2-finger-scrolling,
  impossible to send a middle-click event. I like to think there is a fix for this
  on the Internet that I just haven't come across.

- Wi-Fi is plain stupid. To connect to a Wi-Fi network, choose the network and
  put in the pass. Now for some reason it will never connect to the corresponding
  Wi-Fi network. You need to turn-off Wi-Fi and turn-on again. It should then
  connect to the corresponding Wi-Fi network. However, I've come across Wi-Fi
  networks that just won't no matter what you do. I think these ones are 5GHz
  only but I'm not sure.
  There's also another catch. If you're in an area with 2 or more known Wi-Fi
  networks available, you must *forget* all the other Wi-Fi networks except the
  one you wish to connect to, otherwise you can't switch to another Wi-Fi
  network. Terrible. I don't even know what to search on Google for this one.

- CPU and GPU temperatures aren't read.

- Battery percentage isn't read (you need to always keep a guess of how much time
  longer before the battery runs out, [3-4 hrs]).

- The worst part is getting the audio output working correctly. Holy hell.
  I'll skip the half the pain and put in all the ALSA files that worked for me
  in here. Replace it with `/usr/share/alsa/`. That's all for the ALSA part.

  To get pulseaudio running, we have many interesting hacks. First of all, download
  a one sec blank audio and put this in your crontab:
  ```
  @reboot /usr/bin/mpv /home/me/.sound/one_sec_blank.mp3 --pause --no-video
  ```
  Without this executing in the background - pulseaudio will NEVER work.

  Also, the pulseaudio version that worked fine for me was:
  ```
  $ pulseaudio --version
  pulseaudio 11.1
  ```

  This may not work on later pulseaudio versions. Such as, I compiled pulseaudio 13.x
  but I got this error instead when executing:
  ```
  $ pulseaudio -v
  E: [pulseaudio.bak] channelmap.c: Assertion 'pa_channels_valid(channels)' failed at pulse/channelmap.c:401, function pa_channel_map_init_extend(). Aborting.
  [1]    7415 abort (core dumped)  pulseaudio.bak -v
  ```

  Either way, sometimes pulseaudio 11.1 fails too with a simple:
  ```
  ...
  I: [alsa-sink-HdmiLpeAudio] alsa-sink.c: Starting playback.
  [1]    7517 killed     pulseaudio -v
  ```
  on execution. I was able to workaround this by running the command repeatedly
  immediately after it fails. Think `while true; do pulseaudio -v; done`. There
  comes an instance where it wouldn't fail BUT this one heck of a pulseaudio
  instance will end up spamming these messages in stdout:
  ```
  I: [alsa-sink-HdmiLpeAudio] alsa-sink.c: Starting playback.
  ```
  And put one CPU core to 100% usage (irrespective of whether pulseaudio runs as daemon)
  as long as pulseaudio runs.
  
  **UPDATE:** For some reason it now works fine if I create a script:
  ```
  sleep 10s
  PULSE_RUNTIME_PATH="/run/user/1000/pulse/" /usr/bin/pulseaudio --start
  ```
  and execute it via cron on reboot:
  ```
  @reboot /bin/bash /home/ritiek/.sound/runner.sh
  ```
  The only caveat is that I need to login as soon as the login window shows up,
  otherwise the sound applet won't load.


If you somehow reached this corner and read this text, do yourself a favour and pass such
cheap $165 machines. Go get yourself a better machine ffs.
