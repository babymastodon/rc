import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class FixedSwipeDirectionExtension extends Extension {
    enable() {
        this._patchedGestures = new Map();

        const trackers = new Set([
            Main.overview?._swipeTracker,
            Main.wm?._workspaceAnimation?._swipeTracker,
            Main.overview?._overview?._controls?._workspacesDisplay?._swipeTracker,
            Main.overview?._overview?._controls?._appDisplay?._swipeTracker,
        ]);

        for (const tracker of trackers)
            this._patchGesture(tracker?._touchpadGesture);
    }

    disable() {
        for (const [gesture, {original, replacement}] of this._patchedGestures) {
            if (gesture._touchpadSettings === replacement)
                gesture._touchpadSettings = original;
        }

        this._patchedGestures = null;
    }

    _patchGesture(gesture) {
        const original = gesture?._touchpadSettings;
        if (!original || this._patchedGestures.has(gesture))
            return;

        // Shell currently negates physical swipe deltas only when this setting
        // is true. Always report true here so gestures keep that established
        // direction without changing the actual two-finger scroll setting.
        const replacement = {
            get_boolean(key) {
                return key === 'natural-scroll' || original.get_boolean(key);
            },
        };

        this._patchedGestures.set(gesture, {original, replacement});
        gesture._touchpadSettings = replacement;
    }
}
