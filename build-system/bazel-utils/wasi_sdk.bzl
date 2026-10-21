"""WASI SDK for the build host, whatever its CPU.

The wasm call core (//submodules/TgVoipWebrtc:reference_core_wasm) runs the SDK's clang++ on the
machine doing the build. A plain http_archive pins one host CPU, and the arm64 build fails on Intel
with "Bad CPU type in executable". This rule picks the archive for the host's CPU when the
repository is fetched, so @wasi_sdk_macos / @wasi_sdk_linux work on Apple Silicon and Intel alike.
"""

_VERSION = "33"

# (os, cpu) -> sha256 of wasi-sdk-<version>.0-<cpu>-<os>.tar.gz, from the GitHub release.
_SHA256 = {
    ("macos", "arm64"): "85c997a2665ead91673b5bb88b7d0df3fc8900df3bfa244f720d478187bbdc78",
    ("macos", "x86_64"): "18f3f201ba9734e6a4455b0b6410690395a55e9ffa9f6f5066f66083a94b93b3",
    ("linux", "arm64"): "4f98ee738c7abb45c81a94d1461fc53cc569d1cd01498951c8184d841a027844",
    ("linux", "x86_64"): "0ba8b5bfaeb2adf3f29bab5841d76cf5318ab8e1642ea195f88baba1abd47bce",
}

_BUILD_FILE = """
exports_files(["bin/clang++"])
filegroup(
    name = "all_files",
    srcs = glob(["bin/**", "lib/**", "share/**"]),
    visibility = ["//visibility:public"],
)
"""

def _host_cpu(rctx):
    arch = rctx.os.arch.lower()
    if arch in ["aarch64", "arm64"]:
        return "arm64"
    if arch in ["x86_64", "amd64", "x86-64", "x64"]:
        return "x86_64"
    fail("wasi_sdk: unsupported host CPU '{}'".format(rctx.os.arch))

def _wasi_sdk_impl(rctx):
    os = rctx.attr.os
    cpu = _host_cpu(rctx)
    sha256 = _SHA256.get((os, cpu))
    if sha256 == None:
        fail("wasi_sdk: no archive for {} {}".format(os, cpu))
    name = "wasi-sdk-{v}.0-{cpu}-{os}".format(v = _VERSION, cpu = cpu, os = os)
    rctx.download_and_extract(
        url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-{v}/{name}.tar.gz".format(v = _VERSION, name = name),
        sha256 = sha256,
        strip_prefix = name,
    )
    rctx.file("BUILD.bazel", _BUILD_FILE)

wasi_sdk = repository_rule(
    implementation = _wasi_sdk_impl,
    attrs = {
        "os": attr.string(mandatory = True, values = ["macos", "linux"]),
    },
)
