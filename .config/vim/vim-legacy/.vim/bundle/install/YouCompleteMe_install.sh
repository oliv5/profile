#!/bin/sh
# https://github.com/ycm-core/YouCompleteMe/issues/4134#issuecomment-1446235584
git clone --recurse-submodules https://github.com/ycm-core/YouCompleteMe.git ~/.vim/bundle/plugins/YouCompleteMe
cd ~/.vim/bundle/plugins/YouCompleteMe
#~ ./install.py --all
./install.py --clang-completer --clangd-completer 
