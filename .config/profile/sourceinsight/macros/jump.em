macro SwitchSourceAndHeader()
{
	hbuf = GetCurrentBuf()
	if (hbuf == 0)
		stop

	fname = GetBufName(hbuf)

	len = strlen(fname)
	ext1 = tolower(strmid(fname, len-1, len))
	ext3 = tolower(strmid(fname, len-3, len))
	if (ext1 == "h")
		fname = cat(strmid(fname, 0, len-1), "c")
	else if (ext1 == "c")
		fname = cat(strmid(fname, 0, len-1), "h")
	else if (ext3 == "cpp")
		fname = cat(strmid(fname, 0, len-1), "h")
	
	hbuf = GetBufHandle(fname)
	if (hbuf == 0)
		stop

	SetCurrentBuf(hbuf)
}
