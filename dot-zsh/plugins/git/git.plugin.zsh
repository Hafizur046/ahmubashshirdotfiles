#!/bin/zsh
autoload -Uz zplug
zplug gitstatus
gitstatus_stop "gitstatus$$" && gitstatus_start -s -1 -u -1 -c -1 -d -1 "gitstatus$$"
# Allow for functions in the prompt.
setopt PROMPT_SUBST
autoload -U add-zsh-hook

add-zsh-hook preexec _git_prompt_update_preexec
add-zsh-hook precmd _git_prompt_update
add-zsh-hook chpwd _git_prompt_update
if [[ ${ENV[color_prompt]} = yes ]];then
	ENV[git_clean]='%F{green}' 	# green foreground
	ENV[git_changed]='%F{cyan}'		# cyan forground
	ENV[git_modified]='%F{blue}'  	# yellow foreground
	ENV[git_seperator]='%F{magenta}'	# seperator
	ENV[git_untracked]='%F{cyan}'   	# blue foreground
	ENV[git_conflicted]='%F{red}'  	# red foreground
fi

function _git_prompt_update_preexec() {
	case "$2" in
		git*|hub*|gh*|stg*)
			_git_prompt_update_async "${(q)1}" &!
		;;
	esac
}

_git_prompt_update_async()
{
	sleep 0.1
	local pid
	pid=$(pgrep -fP $$ "$1" 2>/dev/null)
	((pid>$$)) || return
	while sleep 0.1; do
		test -d "/proc/$pid" && continue || break
		_git_prompt_update
	done
}

function _git_prompt_update() {
	emulate -L zsh
	typeset -g  GITSTATUS_PROMPT=''
	typeset -gi GITSTATUS_PROMPT_LEN=0
	${ENV[vfs]:-false} && return 0
	# Call gitstatus_query synchronously. Note that gitstatus_query can also be called
	# asynchronously; see documentation in gitstatus.plugin.zsh.
	local \
		VCS_STATUS_ACTION VCS_STATUS_COMMIT \
		VCS_STATUS_COMMITS_AHEAD VCS_STATUS_COMMITS_BEHIND \
		VCS_STATUS_HAS_CONFLICTED VCS_STATUS_HAS_STAGED \
		VCS_STATUS_HAS_UNSTAGED VCS_STATUS_HAS_UNTRACKED \
		VCS_STATUS_INDEX_SIZE VCS_STATUS_LOCAL_BRANCH \
		VCS_STATUS_NUM_ASSUME_UNCHANGED VCS_STATUS_NUM_CONFLICTED \
		VCS_STATUS_NUM_SKIP_WORKTREE VCS_STATUS_NUM_STAGED \
		VCS_STATUS_NUM_STAGED_DELETED VCS_STATUS_NUM_STAGED_NEW \
		VCS_STATUS_NUM_UNSTAGED VCS_STATUS_NUM_UNSTAGED_DELETED \
		VCS_STATUS_NUM_UNTRACKED VCS_STATUS_PUSH_COMMITS_AHEAD \
		VCS_STATUS_PUSH_COMMITS_BEHIND VCS_STATUS_PUSH_REMOTE_NAME \
		VCS_STATUS_PUSH_REMOTE_URL VCS_STATUS_REMOTE_BRANCH \
		VCS_STATUS_REMOTE_NAME VCS_STATUS_REMOTE_URL \
		VCS_STATUS_RESULT VCS_STATUS_STASHES \
		VCS_STATUS_TAG VCS_STATUS_WORKDIR

	gitstatus_query -d "$PWD" "gitstatus$$"                  || return 1  # error
	[[ $VCS_STATUS_RESULT == 'ok-sync' ]] || return 0  # not a git repo
	local p
	local where  # branch name, tag or commit
	p+="${ENV[git_clean]}%B"
	if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
	    p+=' '
		where=$VCS_STATUS_LOCAL_BRANCH
	elif [[ -n $VCS_STATUS_TAG ]]; then
		p+=' '
		where=$VCS_STATUS_TAG
	else
		p+=' '
		where=${VCS_STATUS_COMMIT[1,8]}
	fi
	(( $#where > 32 )) && where[13,-13]="…"  # truncate long branch names and tags
	p+="${where//\%/%%}%b"             # escape %

	# ⇣42 if behind the remote.
	(( VCS_STATUS_COMMITS_BEHIND )) && p+="${ENV[git_changed]}%B⇣%b${VCS_STATUS_COMMITS_BEHIND}"

	# ⇡42 if ahead of the remote; no leading space if also behind the remote: ⇣42⇡42.
	(( VCS_STATUS_COMMITS_AHEAD  )) && p+="${ENV[git_changed]}%B⇡%b${VCS_STATUS_COMMITS_AHEAD}"

	# ⇠42 if behind the push remote.
	(( VCS_STATUS_PUSH_COMMITS_BEHIND )) && p+="${ENV[git_changed]}%B⇠%b${VCS_STATUS_PUSH_COMMITS_BEHIND}"
	# ⇢42 if ahead of the push remote; no leading space if also behind: ⇠42⇢42.
	(( VCS_STATUS_PUSH_COMMITS_AHEAD  )) && p+="${ENV[git_changed]}%B⇢%b${VCS_STATUS_PUSH_COMMITS_AHEAD}"
	p+="%B${ENV[git_seperator]}:%b${ENV[git_clean]}"
	((
			VCS_STATUS_STASHES
		+	VCS_STATUS_NUM_CONFLICTED
		+	VCS_STATUS_NUM_STAGED
		+	VCS_STATUS_NUM_UNSTAGED
		+	VCS_STATUS_NUM_UNTRACKED
	)) && {
		# *42 if have stashes.
		(( VCS_STATUS_STASHES        )) && p+="${ENV[git_clean]}%B*%b${VCS_STATUS_STASHES}%f"

		# ~42 if have merge conflicts.
		(( VCS_STATUS_NUM_CONFLICTED )) && p+="${ENV[git_conflicted]}%B~%b${VCS_STATUS_NUM_CONFLICTED}%f"

		# +42 if have staged changes.
		(( VCS_STATUS_NUM_STAGED     )) && p+="${ENV[git_modified]}%B+%b${VCS_STATUS_NUM_STAGED}%f"

		# !42 if have unstaged changes.
		(( VCS_STATUS_NUM_UNSTAGED   )) && p+="${ENV[git_modified]}%B!%b${VCS_STATUS_NUM_UNSTAGED}%f"

		# ?42 if have untracked files. It's really a question mark, your font isn't broken.
		(( VCS_STATUS_NUM_UNTRACKED  )) && p+="${ENV[git_untracked]}%B?%b${VCS_STATUS_NUM_UNTRACKED}%f"
	} || p+="✔"
	GITSTATUS_PROMPT="-[${p}%F{red}]"
	# The length of GITSTATUS_PROMPT after removing %f and %F.
	GITSTATUS_PROMPT_LEN="${(m)#${${GITSTATUS_PROMPT//\%\%/x}//\%(f|<->F)}}"
}
