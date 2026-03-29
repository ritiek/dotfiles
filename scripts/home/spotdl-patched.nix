{ pkgs, inputs, ... }:

let
  oldSearchStr = builtins.concatStringsSep "\n" [
    "    def search(self, query, limit=50, offset=0, type=\"track\", *args, **kwargs):"
    "        results = spotapi.Search().search(query)[\"data\"]"
    ""
    "        key = type + \"s\""
    "        items = results.get(key, {}).get(\"items\", [])"
    ""
    "        total = len(items)"
    ""
    "        if limit == -1:"
    "            limit = total"
    ""
    "        end = offset + limit"
    "        sliced = items[offset:end]"
    ""
    "        self._next = lambda: self.search(query, limit=limit, offset=end, type=type)"
    "        return(self._formatAlbum(sliced, total, limit, offset, end))"
  ];

  newSearchStr = builtins.concatStringsSep "\n" [
    "    def search(self, query, limit=50, offset=0, type=\"track\", *args, **kwargs):"
    "        results = spotapi.Song().query_songs(query, limit=limit, offset=offset)"
    "        raw_items = results[\"data\"][\"searchV2\"][\"tracksV2\"][\"items\"]"
    "        total = results[\"data\"][\"searchV2\"][\"tracksV2\"][\"totalCount\"]"
    "        items = []"
    "        for item in raw_items:"
    "            track_data = item[\"item\"][\"data\"]"
    "            track_id = track_data[\"uri\"].replace(\"spotify:track:\", \"\")"
    "            items.append({\"id\": track_id, \"name\": track_data[\"name\"], \"url\": \"https://open.spotify.com/track/\" + track_id})"
    "        self._next = lambda: self.search(query, limit=limit, offset=offset + limit, type=type)"
    "        return {\"tracks\": {\"items\": items, \"total\": total, \"limit\": limit, \"offset\": offset}}"
  ];

  oldSearchFile = pkgs.writeText "old_search.txt" oldSearchStr;
  newSearchFile = pkgs.writeText "new_search.txt" newSearchStr;

  patchScript = pkgs.writeText "patch-spotipyfree.py" ''
    content = open("src/SpotipyFree/Spotify.py").read()

    # Fix isUrl to handle http:// URLs
    content = content.replace(
        'test.startswith("https://open.spotify.com/") or test.startswith("open.spotify")',
        'test.startswith("https://open.spotify.com/") or test.startswith("http://open.spotify.com/") or test.startswith("open.spotify")'
    )

    # Fix track() method: albumId -> trackId
    content = content.replace(
        '        if self.isUrl(trackId):\n            albumId = self.urlToId(trackId)',
        '        if self.isUrl(trackId):\n            trackId = self.urlToId(trackId)'
    )

    # Fix search() method: spotapi.Search -> spotapi.Song().query_songs
    old_search = open("${oldSearchFile}").read()
    new_search = open("${newSearchFile}").read()
    assert old_search in content, "Could not find old search method"
    content = content.replace(old_search, new_search)
    open("src/SpotipyFree/Spotify.py", "w").write(content)
  '';

  pythonOverrides = pyFinal: pyPrev: {
    validators = pyPrev.buildPythonPackage rec {
      pname = "validators";
      version = "0.35.0";
      pyproject = true;
      src = pyPrev.fetchPypi {
        inherit pname version;
        hash = "sha256-mS1sSKTnfIHxtNq6ENFsOpuw27ebOhnqhH/wko5wSXo=";
      };
      build-system = with pyPrev; [ setuptools ];
      pythonRelaxDeps = true;
      doCheck = false;
    };

    readerwriterlock = pyPrev.buildPythonPackage rec {
      pname = "readerwriterlock";
      version = "1.0.9";
      format = "setuptools";
      src = pyPrev.fetchPypi {
        inherit pname version;
        hash = "sha256-t8TMADQ116j/FbMSsKYqiNmAC6YWSviJkfh/i3SPm+o=";
      };
      dependencies = with pyPrev; [ typing-extensions ];
      doCheck = false;
    };

    pyotp = pyPrev.buildPythonPackage rec {
      pname = "pyotp";
      version = "2.9.0";
      format = "setuptools";
      src = pyPrev.fetchPypi {
        inherit pname version;
        hash = "sha256-NGtmQuDb3eO0/1qTC2ZMqCq/oRY1btSMxCx9ZZDTb2M=";
      };
      doCheck = false;
    };

    tls-client = pyPrev.buildPythonPackage rec {
      pname = "tls-client";
      version = "1.0.1";
      format = "wheel";
      src = pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/75/cd/5c735818692927e07980357445569adb6ee204c3332d19c516bae01c6cfa/tls_client-1.0.1-py3-none-any.whl";
        hash = "sha256-L4kVwGQsIibJ4zEgByoq8IKBL2MQ0y9OpNoyLbfTuxw=";
      };
      nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
      buildInputs = [ pkgs.musl ];
      doCheck = false;
    };

    spotapi = pyPrev.buildPythonPackage rec {
      pname = "spotapi";
      version = "1.2.7";
      pyproject = true;
      src = pyPrev.fetchPypi {
        inherit pname version;
        hash = "sha256-x4UA65A4UvxqlDN5upHsPPa5yv8gKZw3kqLou/1xVtY=";
      };
      build-system = with pyPrev; [ setuptools ];
      pythonRelaxDeps = true;
      dependencies = with pyPrev; [
        beautifulsoup4
        colorama
        pillow
        pyFinal.pyotp
        pyFinal.readerwriterlock
        requests
        pyFinal.tls-client
        typing-extensions
        pyFinal.validators
      ];
      doCheck = false;
    };

    spotipyfree = pyPrev.buildPythonPackage rec {
      pname = "spotipyfree";
      version = "1.0.7";
      pyproject = true;
      src = pyPrev.fetchPypi {
        inherit pname version;
        hash = "sha256-uwWdqx63KVZRtOt9Ua7FIX0U8iei/t+z4eY928gMX18=";
      };
      build-system = with pyPrev; [ setuptools ];
      pythonRelaxDeps = true;
      dependencies = with pyPrev; [ pyFinal.spotapi pymongo ];
      doCheck = false;

      postPatch = "python3 ${patchScript}";
    };

  };

  myPython = pkgs.python312.override {
    packageOverrides = pythonOverrides;
  };

  spotdlPatched = myPython.pkgs.buildPythonApplication (finalAttrs: {
    pname = "spotdl";
    version = "4.4.5-unstable-2026-03-26";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "TzurSoffer";
      repo = "spotify-downloader";
      rev = "37ffd06ad8d482d1f4437af9057e77a01768354f";
      hash = "sha256-e3YSuYgZlflt4pC1UNxE3gF0by/pl1yvl518XXkItQc=";
    };

    build-system = with myPython.pkgs; [ hatchling ];

    pythonRelaxDeps = true;

    dependencies =
      with myPython.pkgs;
      [
        beautifulsoup4
        fastapi
        mutagen
        platformdirs
        pydantic
        pykakasi
        python-slugify
        pytube
        rapidfuzz
        requests
        rich
        soundcloud-v2
        spotipy
        spotipyfree
        syncedlyrics
        uvicorn
        websockets
        yt-dlp
        ytmusicapi
      ]
      ++ python-slugify.optional-dependencies.unidecode;

    nativeCheckInputs = with myPython.pkgs; [
      pyfakefs
      pytest-mock
      pytest-subprocess
      pytestCheckHook
      vcrpy
      pkgs.writableTmpDirAsHomeHook
    ];

    disabledTestPaths = [
      "tests/test_init.py"
      "tests/test_matching.py"
      "tests/utils/test_spotify.py"
      "tests/providers/lyrics"
      "tests/types"
      "tests/utils/test_github.py"
      "tests/utils/test_m3u.py"
      "tests/utils/test_metadata.py"
      "tests/utils/test_search.py"
      "tests/utils/test_config.py"
    ];

    disabledTests = [
      "test_convert"
      "test_download_ffmpeg"
      "test_download_song"
      "test_preload_song"
      "test_yt_get_results"
      "test_yt_search"
      "test_ytm_search"
      "test_ytm_get_results"
    ];

    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (pkgs.lib.makeBinPath [ pkgs.ffmpeg ])
    ];

    meta = {
      description = "Download your Spotify playlists and songs along with album art and metadata (patched with SpotipyFree)";
      homepage = "https://github.com/spotDL/spotify-downloader";
      license = pkgs.lib.licenses.mit;
      mainProgram = "spotdl";
    };
  });

  spotdl-patched = pkgs.writeShellScriptBin "spotdl-patched" ''
    exec ${spotdlPatched}/bin/spotdl "$@"
  '';

in
{
  home.packages = [ spotdl-patched ];
}
