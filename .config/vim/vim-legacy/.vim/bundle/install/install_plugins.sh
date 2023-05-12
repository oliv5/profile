#!/bin/sh
LIST_REPO_RECURSIVE="https://github.com/ycm-core/YouCompleteMe.git"
LIST_REPO_SIMPLE="
    https://github.com/vim-scripts/CCVext.vim
    https://github.com/vim-scripts/cctree
    https://github.com/vim-scripts/command-t
    https://github.com/vim-scripts/tagbar
    https://github.com/vim-scripts/buftabs
    https://github.com/vim-scripts/BufLine
    https://github.com/vim-scripts/highlight.vim
    https://github.com/vim-scripts/MultipleSearch.git
    https://github.com/vim-scripts/YankRing.vim
    https://github.com/vim-scripts/yaifa.vim
    https://github.com/vim-scripts/taglist.vim
    https://github.com/vim-scripts/project.vim
    https://github.com/vim-scripts/OmniCppComplete
    https://github.com/vim-scripts/SyntaxComplete
    https://github.com/Rip-Rip/clang_complete
    https://github.com/wenlongche/SrcExpl
    https://github.com/weynhamz/vim-plugin-minibufexpl
    https://github.com/will133/vim-dirdiff
    https://github.com/xolox/vim-easytags
    https://github.com/tpope/vim-commentary
    https://github.com/WolfgangMehner/vim-plugins
    https://github.com/sukima/xmledit
    https://github.com/preservim/nerdtree
    https://github.com/kien/ctrlp.vim
    https://github.com/mtth/scratch.vim
    https://github.com/powerman/vim-plugin-AnsiEsc.git
    https://github.com/cofyc/vim-uncrustify.git
    https://github.com/craigemery/vim-autotag.git
    https://github.com/ludovicchabant/vim-gutentags.git
    https://github.com/skywind3000/gutentags_plus.git
    https://github.com/SirVer/ultisnips.git
    https://github.com/honza/vim-snippets.git
    https://github.com/neoclide/coc.nvim
"

download() {
    local URL
    local DST
    for URL in $LIST_REPO_SIMPLE; do
	DST="$HOME/.vim/bundle/plugins/$(basename "$URL" .git)"
	if [ -d "$DST" ]; then
	    git clone --no-checkout "$URL" "$DST/.tmp"
	    mv "$DST/.tmp/.git" "$DST/.git"
	    rmdir "$DST/.tmp"
	else
	    git clone "$URL" "$DST"
	fi
    done
    for URL in $LIST_REPO_RECURSIVE; do
	DST="$HOME/.vim/bundle/plugins/$(basename "$URL" .git)"
	if [ -d "$DST" ]; then
	    git clone --recurse-submodules --no-checkout "$URL" "$DST/.tmp"
	    mv "$DST/.tmp/.git" "$DST/.git"
	    rmdir "$DST/.tmp"
	else
	    git clone --recurse-submodules "$URL" "$DST"
	fi
    done
}

remove_git_subfolder() {
    find "$HOME/.vim/bundle/plugins/" -name .git -type d -print0 | xargs -r0 rm -r
}

setup_youcompleteme() {
    cd ~/.vim/bundle/plugins/YouCompleteMe
    #~ ./install.py --all
    ./install.py --clang-completer --clangd-completer 
}

# Main
download
remove_git_subfolder
#(setup_youcompleteme)
