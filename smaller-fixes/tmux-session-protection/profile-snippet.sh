
# Keep Terminal sessions alive: the Linux Terminal app's terminal server (ttyd) kills the shell, and
# everything running in it, whenever the app's connection to the VM drops.
# Interactive Terminal shells therefore run inside tmux: a new window re-attaches a session left
# behind by a dropped connection, or starts a new one. Set NO_AUTO_TMUX=1 to skip this.
if [ -z "$TMUX" ] && [ -z "$NO_AUTO_TMUX" ] && [ -t 0 ] && [ -t 1 ] && command -v tmux >/dev/null 2>&1; then
    case $- in
        *i*)
            _orphan=$(tmux list-sessions -F '#{session_attached} #{session_name}' 2>/dev/null | awk '$1 == 0 {print $2; exit}')
            if [ -n "$_orphan" ]; then tmux attach-session -t "$_orphan"; else tmux new-session; fi
            unset _orphan
            ;;
    esac
fi
