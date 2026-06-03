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
- Generates `$BUILD_DIR/.profile.d/000_crystal_font_buildpack.sh` which **at container startup** copies fonts into `$HOME/.java-buildpack/open_jdk_jre/lib/fonts`
- This ensures fonts are present in the JRE lib/fonts directory, exactly where Crystal Reports expects them
- `java_buildpack` installs its JRE during the build; the app-local `.profile.d` script runs **after** that, so the target directory exists

**Lifecycle:**
1. `crystal-font-buildpack` supply → stages fonts to `/home/vcap/app/.crystal-font-buildpack/fonts`
2. `java_buildpack` compile → installs JRE to `/home/vcap/app/.java-buildpack/open_jdk_jre`
3. Container startup → `/home/vcap/app/.profile.d/000_crystal_font_buildpack.sh` copies fonts into `/home/vcap/app/.java-buildpack/open_jdk_jre/lib/fonts`

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

When supply mode is active, the generated `profile.d` script runs at container startup and:
1. Finds staged fonts at `$HOME/.crystal-font-buildpack/fonts`
2. Locates the Java buildpack `lib/fonts` directory under `$HOME/.java-buildpack`
3. Copies all staged fonts into that JRE lib/fonts directory

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
  echo "crystal-font-buildpack: WARNING - unable to find Java buildpack lib/fonts or staged fonts"
fi
```

