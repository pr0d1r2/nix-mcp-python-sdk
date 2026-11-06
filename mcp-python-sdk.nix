{ pkgs }:
let
  py = pkgs.python313Packages;

  # Build-time only: httpx2 2.16 and mcp 2.3 require uv-dynamic-versioning
  # >=0.14.1, and nixpkgs has 0.13.0. Its tests need a .git checkout, so they
  # are skipped; dunamai ~=1.26.1 is relaxed to nixpkgs' 1.25.0.
  uv-dynamic-versioning = py.uv-dynamic-versioning.overridePythonAttrs {
    version = "0.14.1";
    src = pkgs.fetchFromGitHub {
      owner = "ninoseki";
      repo = "uv-dynamic-versioning";
      tag = "v0.14.1";
      hash = "sha256-j9Fv4ryqV3nHYmI1zA/5f6pEYWK55ZBj8/FxT5bicEg=";
    };
    doCheck = false;
    pythonRelaxDeps = [ "dunamai" ];
  };

  # mcp >=2.10 needs httpx2 >=2.10.0, and every httpx2 release from 2.10 on
  # pins httpcore2 to its own version. nixpkgs ships both at 2.3.0, so build
  # the pair from the pydantic/httpx2 monorepo at a newer tag.
  httpxVersion = "2.16.0";
  httpxSrc = pkgs.fetchFromGitHub {
    owner = "pydantic";
    repo = "httpx2";
    tag = "v${httpxVersion}";
    hash = "sha256-oG7mYYb1ZdrcVcTAPUFZx/Ggge7E1Ng7HyrT8YCF+nE=";
  };

  httpcore2 = (py.httpcore2.override { inherit uv-dynamic-versioning; }).overridePythonAttrs {
    version = httpxVersion;
    src = httpxSrc;
  };

  httpx2 =
    (py.httpx2.override { inherit httpcore2 uv-dynamic-versioning; }).overridePythonAttrs
      (old: {
        version = httpxVersion;
        src = httpxSrc;
        # Relaxed: httpx2 >=2.10 declares idna>=3.18, and nixpkgs has 3.15.
        # Shipping a newer idna here is not an option: requests already puts
        # nixpkgs' idna into consumers' closures (semble via huggingface-hub), and
        # two idna copies fail pythonCatchConflictsPhase.
        #
        # Known gap: idna 3.18 added `idna.decode(..., display=True)`, and
        # httpx2.URL.host calls it for punycode (`xn--`) hostnames. With idna 3.15,
        # reading `.host` of such a URL raises TypeError. Requests to those hosts
        # are unaffected (that path uses `raw_host`), and semble's MCP server talks
        # over stdio, so it never builds such URLs. The tests that exercise it are
        # disabled below.
        #
        # Remove this relax and `disabledTests` once nixpkgs-lock ships idna >= 3.18.
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "idna" ];
        # Every case below reads URL.host of a punycode hostname: the known gap
        # described above.
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_equivalent_origins"
          "test_idna_url"
          "test_url_malformed_idna_label_after_ascii_label"
          "test_url_mixed_valid_and_malformed_idna_labels"
          # Unrelated to idna: expects a websocket ping within a 0.1s interval and
          # fails intermittently on a loaded builder.
          "test_keepalive_ping"
        ];
        # 2.16 added websocket tests: they serve through starlette and uvicorn's
        # websockets protocol, and use the `ws` extra (wsproto).
        nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [
          py.starlette
          py.websockets
          py.wsproto
        ];
      });

  version = "2.3.0";
  src = pkgs.fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "python-sdk";
    tag = "v${version}";
    hash = "sha256-CnXi78zYxm0/R4fON/DzRYMSDYM/XM/9SE3s+Cf1BR0=";
  };

  meta = {
    homepage = "https://github.com/modelcontextprotocol/python-sdk";
    license = pkgs.lib.licenses.mit;
  };

  mcp-types = py.buildPythonPackage {
    pname = "mcp-types";
    inherit version src;
    pyproject = true;
    sourceRoot = "${src.name}/src/mcp-types";
    build-system = [
      py.hatchling
      uv-dynamic-versioning
    ];
    dependencies = [
      py.pydantic
      py.typing-extensions
    ];
    pythonImportsCheck = [ "mcp_types" ];
    meta = meta // {
      description = "Model Context Protocol wire types";
    };
  };

  mcp = py.buildPythonPackage {
    pname = "mcp";
    inherit version src;
    pyproject = true;
    build-system = [
      py.hatchling
      uv-dynamic-versioning
    ];
    dependencies = [
      httpx2
      mcp-types
      py.anyio
      py.jsonschema
      py.opentelemetry-api
      py.pydantic
      py.pyjwt
      py.python-multipart
      py.sse-starlette
      py.starlette
      py.typing-extensions
      py.typing-inspection
      py.uvicorn
    ]
    ++ py.pyjwt.optional-dependencies.crypto;
    # The suite spawns subprocesses and binds sockets; the load-server flake
    # check covers what consumers rely on.
    doCheck = false;
    pythonImportsCheck = [
      "mcp"
      "mcp.server.mcpserver"
    ];
    meta = meta // {
      description = "Model Context Protocol Python SDK";
    };
  };
in
{
  default = mcp;
  inherit
    mcp
    mcp-types
    httpx2
    httpcore2
    ;
}
