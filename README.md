# crystal-font-buildpack

Cloud Foundry buildpack that installs Crystal Reports fonts for Java applications.

## Buildpack order

This buildpack is designed to run **before** the Java buildpack in your buildpack order:

```
- crystal-font-buildpack
- java_buildpack
```

## Supported modes

### Supply mode (Recommended for modern CF)

- Runs during the **supply** phase when using the buildpack API v3+ 
- Copies fonts into `deps/$DEPS_IDX/fonts`
- Generates `profile.d/000_crystal_font_buildpack.sh` that appends `-Dsun.java2d.fontpath` to `JAVA_TOOL_OPTIONS`
- Works seamlessly with java_buildpack running in any order
- Set `JAVA_TOOL_OPTIONS` will be available to the Java process at runtime

### Compile mode (Legacy, for single buildpack deployments)

- Runs during compile phase when no multi-buildpack staging is used
- Detects Java runtime via `*/bin/java` in `$DEPS_DIR`
- **Note**: With crystal-font running before java_buildpack, the JRE doesn't exist yet during compile phase, so compile mode is best suited for older single-buildpack setups
- Falls back to `$BUILD_DIR/.java-buildpack/open_jdk_jre/lib/fonts` if JRE not found

## Files

- `bin/detect` - indicates buildpack applies to all apps
- `bin/compile` - legacy compile-mode font installation
- `bin/supply` - supply-mode font installation (recommended)
- `bin/release` - empty release config
- `bin/lib/font_utils.sh` - shared font installation helpers

## Local smoke tests

**Test supply mode:**
```bash
tmp_root=$(mktemp -d)
build_dir="$tmp_root/build"
cache_dir="$tmp_root/cache"
deps_dir="$tmp_root/deps"
mkdir -p "$build_dir" "$cache_dir"

./bin/supply "$build_dir" "$cache_dir" "$deps_dir" 0

# Verify fonts and profile script
ls -1 "$deps_dir/0/fonts" | head -3
cat "$deps_dir/0/profile.d/000_crystal_font_buildpack.sh"
```

**Test compile mode (when java buildpack has already run):**
```bash
tmp_root=$(mktemp -d)
build_dir="$tmp_root/build"
cache_dir="$tmp_root/cache"
deps_dir="$tmp_root/deps"
mkdir -p "$build_dir" "$cache_dir" "$deps_dir/2/open_jdk_jre/bin" "$deps_dir/2/open_jdk_jre/lib"
touch "$deps_dir/2/open_jdk_jre/bin/java"

./bin/compile "$build_dir" "$cache_dir" "$deps_dir"

# Verify fonts installed in JRE lib
ls -1 "$deps_dir/2/open_jdk_jre/lib/fonts" | head -3
```

## Runtime behavior

When supply mode is active, the generated `profile.d` script will:
1. Resolve `$DEPS_DIR` at runtime (default: `/home/vcap/deps`)
2. Point Java to the fonts directory via `-Dsun.java2d.fontpath`
3. Append to any existing `JAVA_TOOL_OPTIONS` without overwriting

Example generated script (with DEPS_IDX=0):
```bash
#!/usr/bin/env bash
FONT_PATH="${DEPS_DIR:-/home/vcap/deps}/0/fonts"
if [[ -n "${JAVA_TOOL_OPTIONS:-}" ]]; then
  export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -Dsun.java2d.fontpath=$FONT_PATH"
else
  export JAVA_TOOL_OPTIONS="-Dsun.java2d.fontpath=$FONT_PATH"
fi
```

