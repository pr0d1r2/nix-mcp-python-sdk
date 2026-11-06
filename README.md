# nix-mcp-python-sdk

<!-- no architecture diagram -->
<!-- no development architecture diagram -->

[![CI](https://github.com/pr0d1r2/nix-mcp-python-sdk/actions/workflows/ci.yml/badge.svg)](https://github.com/pr0d1r2/nix-mcp-python-sdk/actions/workflows/ci.yml) [![NixOS 26.05](https://img.shields.io/badge/NixOS-26.05-blue.svg?logo=nixos)](https://nixos.org)

Nix package for the [Model Context Protocol Python SDK](https://github.com/modelcontextprotocol/python-sdk), published on PyPI as `mcp`, at 2.x. nixpkgs ships mcp 1.x; semble >=0.7 needs `mcp>=2.0,<3.0` for its MCP server. Pre-built binaries are served via [cachix](https://pr0d1r2.cachix.org).

## Packages

| Attribute | Version | Notes |
| --- | --- | --- |
| `default`, `mcp` | 2.3.0 | the SDK |
| `mcp-types` | 2.3.0 | wire types, built from the same upstream tag |
| `httpx2` | 2.16.0 | mcp needs >=2.10.0; nixpkgs has 2.3.0 |
| `httpcore2` | 2.16.0 | pinned exactly by httpx2 |

Consumers should take `httpx2` and `httpcore2` from this flake, not nixpkgs, so the closure holds one copy of each.

## Usage

### As a flake input

```nix
{
  inputs.nix-mcp-python-sdk = {
    url = "github:pr0d1r2/nix-mcp-python-sdk";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # In Python package dependencies:
  nix-mcp-python-sdk.packages.${system}.mcp
}
```

## Known gap: punycode hosts in httpx2

httpx2 2.16 declares `idna>=3.18`, and nixpkgs has idna 3.15. This flake relaxes that bound, because a second idna would collide with the one `requests` already puts in consumers' closures.

idna 3.18 added `idna.decode(..., display=True)`, which `httpx2.URL.host` calls for punycode (`xn--`) hostnames.
With idna 3.15, reading `.host` of such a URL raises `TypeError`.
Requests to those hosts still work, because that path uses `raw_host`.

The httpx2 tests that read `.host` of punycode URLs are disabled. The relax and the disabled tests go away once nixpkgs-lock ships idna >= 3.18.

## Binary cache

The packages are cached via [cachix](https://pr0d1r2.cachix.org). The flake includes `nixConfig` with the substituter, so `nix build` pulls pre-built binaries.

To accept the cache without prompts, add to `~/.config/nix/nix.conf`:

```ini
trusted-substituters = https://pr0d1r2.cachix.org
trusted-public-keys = pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=
```

## License

MIT, matching upstream.
