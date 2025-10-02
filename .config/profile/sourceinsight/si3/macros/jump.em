macro _dirname(a) {
	i = strlen(a)
	while(i > 0) {
		if (a[i] == "\\")
			break
		i = i - 1
	}
	return strmid(a, 0, i)
}

macro _basename(a) {
	i = strlen(a)
	while(i > 0) {
		if (a[i] == "\\")
			break
		i = i - 1
	}
	return strmid(a, i+1, strlen(a))
}

macro _noext(a) {
	i = strlen(a)
	while(i > 0) {
		if (a[i] == ".")
			break
		i = i - 1
	}
	return strmid(a, 0, i)
}

macro _ext(a) {
	i = strlen(a)
	while(i > 0) {
		if (a[i] == ".")
			break
		i = i - 1
	}
	return strmid(a, i+1, strlen(a))
}

macro _open(root, dir, filename, ext) {
	fname = root # "\\" # dir # "\\" # filename # ext
	hbuf = OpenBuf(fname)
	if (hbuf != 0) {
		SetCurrentBuf(hbuf)
		stop
	}
}

macro _try_extension(root, dir, filename, ext) {
	// Change extension
	if (ext == "h") {
		_open(root, dir, filename, ".c")
		_open(root, dir, filename, ".cpp")
	} else if (ext == "c")
		_open(root, dir, filename, ".h")
	} else if (ext == "cpp")
		_open(root, dir, filename, ".h")
	}
}

macro SwitchSourceAndHeader() {
	hbuf = GetCurrentBuf()
	if (hbuf == 0)
		stop

	fname = GetBufName(hbuf)
	len = strlen(fname)

	filename = _basename(_noext(fname))
	last_dir = _basename(_dirname(fname))
	root_path = _dirname(_dirname(fname))
	ext = _ext(fname)

	// Change extension
	_try_extension(root_path, last_dir, filename, ext)

	// Change dir
	if (last_dir == "inc")
		last_dir = "src"
	else if (last_dir == "src")
		last_dir = "inc"

	// Change extension
	_try_extension(root_path, last_dir, filename, ext)
}
