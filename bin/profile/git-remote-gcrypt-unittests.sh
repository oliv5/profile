#!/bin/sh

# OK 1
ut_1() {
  set -e
  KEY=my_gpg_key
  LPWD="$PWD"

  git init --bare bare

  git init local1
  cd local1
  git annex init local1
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$LPWD/bare" local2
  cd "$LPWD/local2"
  git annex enableremote bare gitrepo="$LPWD/bare"
  git annex sync

  cd "$LPWD/local1"
  git annex sync

  cd "$LPWD/local2"
  git annex sync
}

# OK 2
ut_2() {
  set -e
  KEY=my_gpg_key
  LPWD="$PWD"

  git init --bare bare

  git init local1
  cd local1
  git annex init local1
  git remote add bare gcrypt::"$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git annex sync

  git annex initremote bare2 type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$LPWD/bare" local2
  cd "$LPWD/local2"
  git annex enableremote bare2 gitrepo="$LPWD/bare"
  git annex sync

  cd "$LPWD/local1"
  git annex sync

  cd "$LPWD/local2"
  git annex sync
}

# OK 3
ut_3() {
(
  set -e
  KEY=my_gpg_key
  LPWD="$PWD"

  git init --bare bare

  git init local1
  cd local1
  git annex init local1
  git remote add bare gcrypt::"$LPWD/bare"
  git fetch --all
  touch .gitignore
  git add .gitignore
  git annex sync

  git annex initremote bare2 type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$LPWD/bare" local2
  cd "$LPWD/local2"
  git annex enableremote bare2 type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync

    cd "$LPWD/local2"
    git annex sync
  done
)
}

# OK 4
ut_4() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare

  git init local1
  cd local1
  git annex init local1
  git remote add bare gcrypt::"$LPWD/bare"
  git fetch --all
  touch .gitignore
  git add .gitignore
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$LPWD/bare" local2

  cd "$LPWD/local1"
  git annex initremote bare2 type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  cd "$LPWD/local2"
  git annex sync
  git annex enableremote bare2 type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# OK 5
ut_5() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git remote add bare gcrypt::"$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$LPWD/bare" local2
  cd "$LPWD/local2"
  git fetch --all

  cd "$LPWD/local1"
  git remote remove bare
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  cd "$LPWD/local2"
  git annex sync
  git annex enableremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# OK 6 (small error)
ut_6() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git remote add bare gcrypt::"$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  git push bare master
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$LPWD/bare" local2
  cd "$LPWD/local2"
  git fetch --all
  git annex init local2
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git push origin master
  git annex sync

  cd "$LPWD/local1"
  git remote remove bare
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  cd "$LPWD/local2"
  git annex sync
  git annex enableremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$LPWD/bare"
  git annex sync

  echo "*********************************"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Test 7
ut_7() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  SRV=ssh://localhost
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git remote add bare gcrypt::"$SRV$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  git push bare master
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$SRV$LPWD/bare" local2
  cd "$LPWD/local2"
  git fetch --all
  git annex init local2
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git push origin master
  git annex sync

  cd "$LPWD/local1"
  git remote remove bare
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  git annex sync

  cd "$LPWD/local2"
  git annex sync
  git remote remove origin
  git annex enableremote bare gitrepo="$SRV$LPWD/bare"
  git annex sync

  echo "*********************************"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Test 8 rsync: NOK, rsync-repo cannot be pushed + need rsyncd running on remote
ut_8() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  SRV=rsync://localhost
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git remote add bare gcrypt::"$SRV$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  git push bare master
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$SRV$LPWD/bare" local2
  cd "$LPWD/local2"
  git fetch --all
  git annex init local2
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git push origin master
  git annex sync

  cd "$LPWD/local1"
  git remote remove bare
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  git annex sync

  cd "$LPWD/local2"
  git annex sync
  git remote remove origin
  git annex enableremote bare gitrepo="$SRV$LPWD/bare"
  git annex sync

  echo "*********************************"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Test 9 rsync: NOK, need rsyncd running on remote
ut_9() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  SRV=rsync://localhost:
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  git annex sync
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$SRV$LPWD/bare" local2
  cd "$LPWD/local2"
  git annex init local2
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git annex sync
  git remote remove origin
  git annex enableremote bare gitrepo="$SRV$LPWD/bare"
  git annex sync

  echo "*********************************"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Test 10 sftp: NOK, sftp 
ut_10() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  SRV=sftp://localhost:22
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  git annex sync
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  git annex sync

  cd "$LPWD"
  git clone gcrypt::"$SRV$LPWD/bare" local2
  cd "$LPWD/local2"
  git annex init local2
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git annex sync
  git remote remove origin
  git annex enableremote bare gitrepo="$SRV$LPWD/bare"
  git annex sync

  echo "*********************************"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Test 11 ssh: bare annex init, push to bare before init remote annex, OK
ut_11() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  SRV=ssh://localhost
  mkdir "$LPWD"
  cd "$LPWD"

  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git remote add bare gcrypt::"$SRV$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  git push bare master

  cd "$LPWD"
  git clone gcrypt::"$SRV$LPWD/bare" local2
  cd "$LPWD/local2"
  git fetch --all
  git annex init local2
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git push origin master

  cd "$LPWD/local1"
  git remote remove bare
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  git annex sync
  ls > data
  git annex add data
  git annex copy data --to bare
  git annex sync

  cd "$LPWD/local2"
  git annex sync
  git remote remove origin
  git annex enableremote bare gitrepo="$SRV$LPWD/bare"
  git annex sync
  git annex get data

  echo "*********************************"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Test 12 ssh: bare annex init, init remote annex, then push/sync, enable remote full
ut_12() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  SRV=ssh://localhost
  mkdir "$LPWD"
  cd "$LPWD"

  echo "####"
  git init --bare bare
  cd "$LPWD/bare"
  git annex init bare

  echo "####"
  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  #git push bare master
  git annex sync

  echo "####"
  cd "$LPWD"
  git clone gcrypt::"$SRV$LPWD/bare" local2
  cd "$LPWD/local2"
  git annex init local2
  git annex enableremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git push origin master

  echo "####"
  cd "$LPWD/local1"
  git annex sync
  ls > data
  git annex add data
  git annex copy data --to bare
  git annex sync

  echo "####"
  cd "$LPWD/local2"
  git annex sync
  git annex get data

  echo "####"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Test 13 ssh: NO bare annex init (full gcrypt init), init remote annex, then push/sync, enable remote full
ut_13() {
(
  set -e
  set -vx
  KEY=my_gpg_key
  LPWD="$PWD/test_$(date +%s)"
  SRV=ssh://localhost
  mkdir "$LPWD"
  cd "$LPWD"

  echo "####"
  git init --bare bare
  cd "$LPWD/bare"

  echo "####"
  cd "$LPWD"
  git init local1
  cd "$LPWD/local1"
  git annex init local1
  git annex initremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  touch .gitignore
  git add .gitignore
  git commit -m 'My first commit'
  #git push bare master
  git annex sync

  echo "####"
  cd "$LPWD"
  git clone gcrypt::"$SRV$LPWD/bare" local2
  cd "$LPWD/local2"
  git annex init local2
  git annex enableremote bare type=gcrypt encryption=pubkey keyid="$KEY" gitrepo="$SRV$LPWD/bare"
  touch .gitignore2
  git add .gitignore2
  git commit -m 'My second commit'
  git push origin master

  echo "####"
  cd "$LPWD/local1"
  git annex sync
  ls > data
  git annex add data
  git annex copy data --to bare
  git annex sync

  echo "####"
  cd "$LPWD/local2"
  git annex sync
  git annex get data

  echo "####"
  for T in 1 2; do
    cd "$LPWD/local1"
    git annex sync
    cd "$LPWD/local2"
    git annex sync
  done
)
}

# Main
"$@"
