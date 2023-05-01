#!/usr/bin/python3
# Download VSCode extensions for offline installation
# ex1: https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/cpptools/1.15.3/vspackage?targetPlatform=linux-x64
# ex2: https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ryuta46/vsextensions/multi-command/1.6.0/vspackage

#import requests
import urllib
import urllib.request
import os.path

platform = 'linux-x64'
template = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{extension}/{version}/vspackage'
extensions = (
    # https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools
    { 'publisher' : 'ms-vscode', 'extension' : 'cpptools', 'version' : '1.15.3', 'platform' : True },
    # https://marketplace.visualstudio.com/items?itemName=ryuta46.multi-command
    { 'publisher' : 'ryuta46', 'extension' : 'multi-command', 'version' : '1.6.0' },
    # https://marketplace.visualstudio.com/items?itemName=tomhultonharrop.switch-corresponding
    { 'publisher' : 'tomhultonharrop', 'extension' : 'switch-corresponding', 'version' : '0.6.1' },
    # https://marketplace.visualstudio.com/items?itemName=ms-python.python
    { 'publisher' : 'ms-python', 'extension' : 'python', 'version' : '2023.7.11181009' },
    # https://marketplace.visualstudio.com/items?itemName=ms-python.vscode-pylance
    { 'publisher' : 'ms-python', 'extension' : 'vscode-pylance', 'version' : '2023.4.41' },
    # https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter
    { 'publisher' : 'ms-toolsai', 'extension' : 'jupyter', 'version' : '2023.4.1011191312' },
    # https://marketplace.visualstudio.com/items?itemName=cschlosser.doxdocgen
    { 'publisher' : 'cschlosser', 'extension' : 'doxdocgen', 'version' : '1.4.0' },
    # https://marketplace.visualstudio.com/items?itemName=jaydenlin.ctags-support
    { 'publisher' : 'jaydenlin', 'extension' : 'ctags-support', 'version' : '1.0.22' },
    # https://marketplace.visualstudio.com/items?itemName=hars.CppSnippets
    { 'publisher' : 'hars', 'extension' : 'CppSnippets', 'version' : '0.0.15' },
    # https://marketplace.visualstudio.com/items?itemName=twxs.cmake
    { 'publisher' : 'twxs', 'extension' : 'cmake', 'version' : '0.0.17' },
    # https://marketplace.visualstudio.com/items?itemName=ms-vscode.makefile-tools
    { 'publisher' : 'ms-vscode', 'extension' : 'makefile-tools', 'version' : '0.8.1' },
)

error = False
for ext in extensions:
    url = template.format(publisher=ext['publisher'], extension=ext['extension'], version=ext['version'])
    if 'platform' in ext and ext['platform'] == True:
        url = url + '?targetPlatform=' + platform
    name = '%s.%s.%s.%s.vsix' % (ext['publisher'], ext['extension'], ext['version'], platform)
    print('Name: ' + name)
    print('Url: ' + url)
    if not os.path.isfile(name):
        try:
            #requests.get(url, allow_redirects=True)
            urllib.request.urlretrieve(url, name)
            print('...done...')
        except Exception as e:
            print('...error downloading file...')
            error = True
    else:
        print('...skip existing file...')
    print()

print('Status: an error happened...' if error else 'Status: OK')
