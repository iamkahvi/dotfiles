# Adding dev
[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

if [ -e /Users/kahvipatel/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/kahvipatel/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby() {
	source /opt/dev/sh/chruby/chruby.sh
	chruby "$@"
}; }
