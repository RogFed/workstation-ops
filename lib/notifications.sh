#!/usr/bin/env bash

notify_if_enabled() {
    if ! bool_is_true "$ENABLE_NOTIFICATIONS"; then
        return 0
    fi

    if have_command "$NOTIFY_SEND_BIN"; then
        if "$NOTIFY_SEND_BIN" "$@"; then
            return 0
        fi

        log "Notification skipped: $NOTIFY_SEND_BIN failed"
        return 0
    fi

    log "Notification skipped: $NOTIFY_SEND_BIN not available"
}
