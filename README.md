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
- Stages fonts in `$BUILD_DIR/.crystal-font-buildpack/fonts` during the build
- Pre-seeds fonts into `$BUILD_DIR/.java-buildpack/open_jdk_jre/lib/fonts` during staging
- Generates `$BUILD_DIR/.profile.d/000_crystal_font_buildpack.sh` as a runtime fallback that copies fonts into the detected Java `lib/fonts` directory
- This ensures fonts are present in the JRE lib/fonts directory, exactly where Crystal Reports expects them
- If app-local `.profile.d` is not sourced in your environment, the pre-seeded path still gives Java buildpack the expected font directory in the droplet

**Lifecycle:**
1. `crystal-font-buildpack` supply → stages fonts to `/home/vcap/app/.crystal-font-buildpack/fonts`
2. `crystal-font-buildpack` supply → pre-seeds `/home/vcap/app/.java-buildpack/open_jdk_jre/lib/fonts`
3. `java_buildpack` compile → installs or reuses JRE under `/home/vcap/app/.java-buildpack`
4. Container startup → `/home/vcap/app/.profile.d/000_crystal_font_buildpack.sh` re-copies fonts if needed

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
build_dir="$tmp_root/build"
cache_dir="$tmp_root/cache"

# Simulate java_buildpack having installed the JRE
mkdir -p "$HOME/.java-buildpack/open_jdk_jre/lib/fonts" "$build_dir" "$cache_dir"

# Run supply (stages fonts)
./bin/supply "$build_dir" "$cache_dir" "$tmp_root/deps" 0

# Verify fonts were pre-seeded during staging
ls -1 "$build_dir/.java-buildpack/open_jdk_jre/lib/fonts" | head -3

# Simulate container startup
cp -R "$build_dir/." "$HOME/"
source "$HOME/.profile.d/000_crystal_font_buildpack.sh"

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

When supply mode is active, the buildpack:
1. Stages fonts at `$HOME/.crystal-font-buildpack/fonts`
2. Pre-seeds `$HOME/.java-buildpack/open_jdk_jre/lib/fonts` during staging
3. Also installs a `.profile.d` fallback that locates the active Java buildpack `lib/fonts` directory and copies fonts again if needed

Example generated script (with DEPS_IDX=0):
```bash
#!/usr/bin/env bash
STAGED_FONTS="${HOME}/.crystal-font-buildpack/fonts"
JRE_ROOT="${HOME}/.java-buildpack"
JRE_FONTS_DIR=""
if [[ -d "${JRE_ROOT}" ]]; then
  JRE_FONTS_DIR=$(find "${JRE_ROOT}" -type d -path '*/lib/fonts' | head -n 1)
fi
if [[ -n "${JRE_FONTS_DIR}" ]] && [[ -d "${STAGED_FONTS}" ]]; then
  cp "${STAGED_FONTS}"/* "${JRE_FONTS_DIR}/" 2>/dev/null || true
  echo "crystal-font-buildpack: Installed fonts into ${JRE_FONTS_DIR}"
else
  echo "crystal-font-buildpack: WARNING - runtime fallback could not find Java buildpack lib/fonts or staged fonts"
fi
```

