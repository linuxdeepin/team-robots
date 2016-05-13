#!/bin/bash

# Copyright (C) 2016 Deepin Technology Co., Ltd.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

### Depends
depends=(git sed awk /usr/sbin/sendmail)

### Get project name and tag

# examples:
#   GERRIT_PROJECT=only-for-test
#   GERRIT_REFNAME=refs/tags/v1.2.1.2

if [ -z "${GERRIT_PROJECT}" ]; then
    GERRIT_PROJECT="$1"
fi
if [ -z "${GERRIT_REFNAME}" ]; then
    GERRIT_REFNAME="$2"
fi
prj_name="${GERRIT_PROJECT}"
tag_name="${GERRIT_REFNAME##*/}"
gerrit_url="https://cr.deepin.io"
gerrit_web_url="https://cr.deepin.io/#/admin/projects"

### Config

email_receivers=(
  'deepin-developers@googlegroups.com'

  # magic email address to reply github comments for https://github.com/linuxdeepin/developer-center/issues/41
  'reply+0117e56b4608f9d421fbe1c1981f234ef326a8ccf6babcaa92cf000000011320cb4092a169ce0823d885@reply.github.com'

  # test only for https://github.com/fasheng/test-only/issues/1
  # 'reply+0117dec57a13e822e0a0b9facb787c2dbf7389d667ca1c5192cf00000001131ef3bd92a169ce08b393c8@reply.github.com'
)
tasklist_file="./tasklist"
max_git_log_num=5

github_deepin_org="linuxdeepin"

### Help functions
msg() {
  local mesg="$1"; shift
  printf "==> ${mesg}\n" "$@" >&2
}

msg2() {
  local mesg="$1"; shift
  printf "  -> ${mesg}\n" "$@" >&2
}

warning() {
  local mesg="$1"; shift
  printf "==> WARNING: ${mesg}\n" "$@" >&2
}

error() {
  local mesg="$1"; shift
  printf "==> ERROR: ${mesg}\n" "$@" >&2
}

abort() {
  local mesg="$1"; shift
  printf "==> ERROR: ${mesg}\n" "$@" >&2
  env # for debug
  exit 1
}

is_cmd_exists() {
  if type -a "$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

ensure_cmd_exists() {
  if ! is_cmd_exists "$1"; then
    abort "command not exists: $1"
  fi
}

lock_tasklist() {
  if [ -e "${tasklist_file}.lock" ]; then
    warning "${tasklist_file}.lock already exists"
    return 1
  else
    touch "${tasklist_file}.lock"
    msg "setup traps"
    trap unlock_tasklist EXIT SIGHUP SIGINT SIGTERM
    return 0
  fi
}
unlock_tasklist() {
  msg "cleanup lock file"
  rm -f "${tasklist_file}.lock"
}

is_public_prj() {
  msg "Checking if is public project: $1"
  # use ":@" in https url to ignore authentication
  if timeout 120 git ls-remote "https://:@cr.deepin.io/$1" &>/dev/null; then
    msg2 "is a public project"
    return 0
  else
    msg2 "not a public project"
    return 1
  fi
}

is_github_prj_exists() {
  # use ":@" in https url to ignore authentication
  if timeout 120 git ls-remote "https://:@github.com/${github_deepin_org}/$1" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

is_task_exists() {
  if grep -q "^$1\$" "${tasklist_file}" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

append_task() {
  if [ -z "$1" -o -z "$2" ]; then
    warning "invalid project name or tag: $1 $2"
    return
  fi
  local task_item="$1 $2"
  if is_task_exists "${task_item}"; then
    warning "task already exists: ${task_item}"
  else
    echo "${task_item}" >> "${tasklist_file}"
    msg "append new task: ${task_item}"
  fi
}

dispatch_tasks() {
  msg "Dispatch left tasks..."
  local error_occurred=
  while true; do
    if ! is_task_left; then
      msg2 "all tasks done"
      break
    fi

    local task="$(get_next_task)"
    if ! start_task "${task}"; then
      error_occurred=t
      abort "task failed: ${task}"
    else
      mark_task_finished "${task}"
    fi
  done
  if [ -z "${error_occurred}" ]; then
    return 0
  else
    return 1
  fi
}

get_next_task() {
  head -1 "${tasklist_file}"
}

is_task_left() {
  if [ ! -f "${tasklist_file}" ]; then
    return 1
  fi
  local task_num="$(cat "${tasklist_file}" | wc -l)"
  if [ "${task_num}" -eq 0 ]; then
    return 1
  fi
  return 0
}

mark_task_finished() {
  msg2 "mark task finished: $1"
  # convert "lastore/lastore-daemon 0.9.18.3" to lastore\/lastore-daemon 0.9.18.3
  local keywords="$(echo "$1" | sed 's=/=\\/=g')"
  msg2 "task keywords: ${keywords}"
  sed -i "/^${keywords}\$/d" "${tasklist_file}"
}

start_task() {
  msg "Start task: $1"
  local prj="$(echo "$1" | awk '{print $1}')"
  local tag="$(echo "$1" | awk '{print $2}')"
  local github_prj_name="$(basename ${prj})" # there is no categories in github project path

  if [ -z "${prj}" -o -z "${tag}" ]; then
    warning "invalid task: $1"
    # do not treat invalid task as an error, so just return 0
    return 0
  fi

  # update git repo
  msg2 "update project git repo"
  if ! update_prj_repo "${prj}"; then
    error "update git repo failed: ${prj}"
    return 1
  fi

  # run commands under git repo directory
  (
    cd "repos/${prj}"

    # check if tag valid
    if ! is_valid_tag "${tag}"; then
      error "invalid tag: ${tag}"
      exit 1
    fi

    changlog=
    github_compare_url=

    # find previous differ tag name
    prev_tag_desc="$(git describe --long --tags "${tag}"~1 2>/dev/null)"
    if [ "$?" -eq 0 ]; then
      prev_tag="$(echo ${prev_tag_desc} | awk -F- '{print $1}')"
      msg2 "found previous tag: ${prev_tag}"
      changelog="$(git log --graph --pretty=format:'%h - %s (%cr) <%an>' --abbrev-commit ${prev_tag}...${tag})"
      github_compare_url="https://github.com/${github_deepin_org}/${github_prj_name}/compare/${prev_tag}...${tag}"
    else
      # # there is no tag before, just get all logs since the first commit
      changelog="$(git log --graph --pretty=format:'%h - %s (%cr) <%an>' --abbrev-commit ${tag})"
      github_compare_url="https://github.com/${github_deepin_org}/${github_prj_name}/commits/${tag}"
    fi

    # limit changelog max line
    changelog="$(echo "${changelog}" | head -${max_git_log_num})"

    # build email content, be careful, Message-ID is necessary or
    # github will ignore our email
    mail_file="$(mktemp /tmp/mail.XXXXXXXX)"
    echo "Subject: Release ${github_prj_name} ${tag}" >> "${mail_file}"
    echo 'Message-ID: twsegac21r4.jenkins@deepin.com>' >> "${mail_file}"
    echo 'Content-Type: text/plain;charset="utf-8"' >> "${mail_file}"
    echo "" >> "${mail_file}"
    echo "Release ${github_prj_name} ${tag}" >> "${mail_file}"
    echo "${gerrit_web_url}/${prj}" >> "${mail_file}"
    echo "" >> "${mail_file}"
    echo "${changelog}" >> "${mail_file}"
    echo "..." >> "${mail_file}"
    if is_github_prj_exists "${github_prj_name}"; then
      echo "More changes to see ${github_compare_url}" >> "${mail_file}"
    else
      echo "NOTE: There is no github mirror project for ${github_prj_name}" >> "${mail_file}"
    fi

    msg2 "email content:"
    cat "${mail_file}"

    # send email
    success_num=0
    for receiver in "${email_receivers[@]}"; do
      msg2 "send email to ${receiver}"
      if timeout 300 /usr/sbin/sendmail "${receiver}" < "${mail_file}"; then
        ((success_num++))
      fi
    done

    rm -f "${mail_file}"

    # report error only when no one receive email
    if [ "${success_num}" -eq 0 ]; then
      error "send email failed: ${email_receivers[@]}"
      exit 1
    fi
  )
  if [ "$?" -ne 0 ]; then
    return 1
  fi
}

update_prj_repo() {
  # check if git repo exists
  (cd "repos/$1" 2>/dev/null && git rev-parse)
  if [ "$?" -ne 0 ]; then
    msg2 "clone repo ${gerrit_url}/$1"
    rm -rf "$1"
    git clone --mirror "${gerrit_url}/$1" "repos/$1"
  else
    msg2 "fetch repo"
    (cd "repos/$1" && git fetch)
  fi
}

is_valid_tag() {
  # TODO: check repeat tag?
  # if is_tag_exists "$1" -a is_not_repeat_tag "$1"; then
  if is_tag_exists "$1"; then
    return 0
  else
    return 1
  fi
}

is_tag_exists() {
  if git show-ref --verify -q --tags -d refs/tags/"$1"; then
    return 0
  else
    return 1
  fi
}

# repeat tag means the same commit with other tags
is_not_repeat_tag() {
  local commit="$(get_tag_ref_commit $1)"
  local tags="$(git show-ref --tags -d | grep "^${commit}" | sed -e 's,.* refs/tags/,,' -e 's/\^{}//')"
  local tags_num="$(echo "${tags}" | wc -l)"
  if [ "${tags_num}" -eq 1 ]; then
    return 0
  else
    error "repeat tags: ${tags}"
    return 1
  fi
}
get_tag_ref_commit() {
  # get tag referenced commit id
  git show-ref --tags -d "$1" | grep '\^{}$' | awk '{print $1}'
}

### Main loop

# check depends
for cmd in "${depends[@]}"; do
  ensure_cmd_exists "${cmd}"
done

if [ -n "${prj_name}" ]; then
  if is_public_prj "${prj_name}"; then
    task="${prj_name} ${tag_name}"
    if ! start_task "${task}"; then
      # append failed task to tasklist
      append_task "${prj_name}" "${tag_name}"
    fi
  fi
else
  # dispatch left failed tasks
  if ! dispatch_tasks; then
      abort "error occurred"
  fi
fi
