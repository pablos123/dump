#!/usr/bin/env bats

load helpers

setup() {
    POKIDLE_TEST_HOME="$BATS_TMPDIR/home.$$"
    mkdir -p "$POKIDLE_TEST_HOME"
    export HOME="$POKIDLE_TEST_HOME"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CACHE_HOME="$HOME/.cache"
    # Override systemctl: the test must not poke real user services.
    export PATH="$BATS_TMPDIR/bin.$$:$PATH"
    mkdir -p "$BATS_TMPDIR/bin.$$"
    cat > "$BATS_TMPDIR/bin.$$/systemctl" <<'EOF'
#!/bin/bash
# stub: log args, exit 0
echo "stub-systemctl: $*" >> "$HOME/systemctl.log"
exit 0
EOF
    chmod +x "$BATS_TMPDIR/bin.$$/systemctl"
}

teardown() {
    rm -rf "$POKIDLE_TEST_HOME" "$BATS_TMPDIR/bin.$$"
}

@test "pokidle setup creates config + unit + symlink and skips enable" {
    run "$REPO_ROOT/pokidle" setup
    [ "$status" -eq 0 ]
    [ -f "$XDG_CONFIG_HOME/pokidle/biomes.json" ]
    [ -f "$XDG_CONFIG_HOME/systemd/user/pokidle.service" ]
    [ -L "$HOME/.local/bin/pokidle" ]
    grep -q 'daemon-reload' "$HOME/systemctl.log"
    ! grep -q 'enable --now' "$HOME/systemctl.log"
}

@test "pokidle setup --enable also enables the unit" {
    run "$REPO_ROOT/pokidle" setup --enable
    [ "$status" -eq 0 ]
    grep -q 'enable --now' "$HOME/systemctl.log"
}

@test "pokidle setup is idempotent (no overwrite without --force)" {
    "$REPO_ROOT/pokidle" setup
    echo '{"manual":"edit"}' > "$XDG_CONFIG_HOME/pokidle/biomes.json"
    "$REPO_ROOT/pokidle" setup
    run cat "$XDG_CONFIG_HOME/pokidle/biomes.json"
    [ "$output" = '{"manual":"edit"}' ]
}

@test "pokidle setup --force overwrites config" {
    "$REPO_ROOT/pokidle" setup
    echo '{"manual":"edit"}' > "$XDG_CONFIG_HOME/pokidle/biomes.json"
    "$REPO_ROOT/pokidle" setup --force
    run jq '.biomes | length' "$XDG_CONFIG_HOME/pokidle/biomes.json"
    [ "$output" = "18" ]
}
