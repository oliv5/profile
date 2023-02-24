macro Indented(hbuf) {
	numLines = GetBufLineCount(hbuf)
	i = numLines - 1
	while(i != 1) {
		link = GetSourceLink(hbuf, i)
		if (link == "") {
			line_text = GetBufLine(hbuf, i)
			PutBufLine(hbuf, i, " " # line_text)
		}
		i = i - 1
	}
	replaceInBuf(hbuf, "^  *", "    ", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
	replaceInBuf(hbuf, "^    \t*", "    ", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
}

macro GroupedIndented(hbuf) {
	numLines = GetBufLineCount(hbuf)
	i = numLines - 1
	while(i != 1) {
		link = GetSourceLink(hbuf, i)
		if (link == "") {
			line_text = GetBufLine(hbuf, i)
			PutBufLine(hbuf, i, " " # line_text)
		} else {
			InsBufLine(hbuf, i, "")
		}
		i = i - 1
	}
	replaceInBuf(hbuf, "^  *", "    ", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
	replaceInBuf(hbuf, "^    \t*", "    ", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
}

macro SameHeader(hbuf) {
	numLines = GetBufLineCount(hbuf)
	link_text = ""
	i = 1
	while(i < numLines) {
		link = GetSourceLink(hbuf, i)
		if (link == "") {
			line_text = GetBufLine(hbuf, i)
			PutBufLine(hbuf, i, link_text # line_text)
		} else {
			link_text = GetBufLine(hbuf, i)
		}
		i = i + 1
	}
	replaceInBuf(hbuf, "^\\([^:]*: \\) *", "\\1", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
	replaceInBuf(hbuf, "^\\([^:]*: \\)\\t*", "\\1", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
}

macro SameHeaderCompact(hbuf) {
	numLines = GetBufLineCount(hbuf)
	last_link = GetSourceLink(hbuf, 1)
	link_text = ""
	i = 1
	while(i < numLines) {
		link = GetSourceLink(hbuf, i)
		if (link == "") {
			line_text = GetBufLine(hbuf, i)
			PutBufLine(hbuf, i, link_text # line_text)
			SetSourceLink(hbuf, i, last_link.file, last_link.ln)
			last_link.ln = last_link.ln + 1
		} else {
			link_text = GetBufLine(hbuf, i)
			last_link = link
			DelBufLine(hbuf, i)
			numLines = numLines - 1
			i = i - 1
		}
		i = i + 1
	}
	replaceInBuf(hbuf, "^\\([^:]*: \\) *", "\\1", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
	replaceInBuf(hbuf, "^\\([^:]*: \\)\\t*", "\\1", 0, numLines, false/*matchcase*/, true/*regexp*/, false/*wholeword*/, false/*confirm*/)
}

macro RemoveErrors(hbuf) {
	numLines = GetBufLineCount(hbuf)
	sel = SearchInBuf(hbuf, "^---- .* Search Errors Encountered (.*) ----.*", 0, 0, true/*matchcase*/, true/*regexp*/, false/*wholeword*/)
	if (sel == "")
		stop
	while(sel.lnFirst < numLines) {
		DelBufLine(hbuf, sel.lnFirst)
		numLines = numLines - 1
	}
}

event DocumentChanged(sFile) {
	if (strlen(sFile)>=14 && strmid(sFile, strlen(sFile)-14, strlen(sFile)) == ".SearchResults") {
		hbuf = GetBufHandle(sFile)
		if hbuf == hNil
			stop
		if (! IsBufDirty(hbuf)) // Prevent rentry
			stop
		RemoveErrors(hbuf)
		SameHeaderCompact(hbuf)
		SaveBuf(hbuf)
	}
}
