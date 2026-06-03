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
- Stages fonts in `deps/$DEPS_IDX/fonts` during the build
- Generates `profile.d/000_crystal_font_buildpack.sh` which **at container startup** copies fonts into `$HOME/.java-buildpack/open_jdk_jre/lib/fonts`
- This ensures fonts are present in the JRE lib/fonts directory, exactly where Crystal Reports expects them
- `java_buildpack` installs its JRE during the build; the profile.d script runs **after** that, so the target directory exists

**Lifecycle:**
1. `crystal-font-buildpack` supply → stages fonts to `/home/vcap/deps/0/fonts`
2. `java_buildpack` compile → installs JRE to `/home/vcap/app/.java-buildpack/open_jdk_jre`
3. Container startup → profile.d copies fonts into `/home/vcap/app/.java-buildpack/open_jdk_jre/lib/fonts`

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
export HOME="$tmp_root/home"
export DEPS_DIR="$tmp_root/deps"
build_dir="$tmp_root/build"
cache_dir="$tmp_root/cache"

# Simulate java_buildpack having installed the JRE
mkdir -p "$HOME/.java-buildpack/open_jdk_jre/lib/fonts" "$build_dir" "$cache_dir"

# Run supply (stages fonts)
./bin/supply "$build_dir" "$cache_dir" "$DEPS_DIR" 0

# Simulate container startup
source "$DEPS_DIR/0/profile.d/000_crystal_font_buildpack.sh"

# Verify fonts are now in the JRE lib/fonts directory
ls -1 "$HOME/.java-buildpack/open_jdk_jre/lib/fonts"
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

When supply mode is active, the generated `profile.d` script runs at container startup and:
1. Resolves `$DEPS_DIR` (default: `/home/vcap/deps`) to find staged fonts
2. Finds the JRE lib/fonts directory at `$HOME/.java-buildpack/open_jdk_jre/lib/fonts`
3. Copies all staged fonts into the JRE lib/fonts directory

Example generated script (with DEPS_IDX=0):
```bash
#!/usr/bin/env bash
STAGED_FONTS="${DEPS_DIR:-/home/vcap/deps}/0/fonts"
JRE_FONTS_DIR="${HOME}/.java-buildpack/open_jdk_jre/lib/fonts"
if [[ -d "${JRE_FONTS_DIR}" ]] && [[ -d "${STAGED_FONTS}" ]]; then
  cp "${STAGED_FONTS}"/* "${JRE_FONTS_DIR}/" 2>/dev/null || true
  echo "crystal-font-buildpack: Installed fonts into ${JRE_FONTS_DIR}"
else
  echo "crystal-font-buildpack: WARNING - JRE fonts dir not found at ${JRE_FONTS_DIR}, skipping"
fi
```

