module FileSources

export StreamSource,
       FileSource,
       CmdSource,
       reset,
       next,
       start,
       stop

abstract StreamSource

type FileSource <: StreamSource
	filename::AbstractString
	file::IOStream
	
    wordIndex::Int64
    bitIndex::Int64
    tempWord::UInt64

	function FileSource(filename::AbstractString)
		this = new()
		this.filename = filename

		this.wordIndex = 0
		this.bitIndex = 0
		
		return this
	end
end # FileSource

type CmdSource <: StreamSource
	cmd::Cmd
	file
	proc
	tmpf::AbstractString
	
    wordIndex::Int64
    bitIndex::Int64
    tempWord::UInt64

	function CmdSource(cmd)
		this = new()
		this.cmd = cmd

		this.wordIndex = 0
		this.bitIndex = 0
		
		return this
	end
end # FileSource

function start(bits::FileSource)
	bits.file = open(bits.filename, "r")
	bits.tempWord = read(bits.file, UInt64)
end

function start(bits::CmdSource)
	tmpfname ="/run/shm/bits-" * randstring(16)
	bits.tmpf=tmpfname

	touch(tmpfname)
	run(pipeline(bits.cmd, tmpfname))

	bits.file = open(bits.tmpf, "r")
	bits.tempWord = read(bits.file, UInt64)
end

function reset(bits::FileSource)
	bits.wordIndex = 0
	bits.bitIndex = 0
	stop(bits)
	start(bits)
end

function reset(bits::CmdSource)
	bits.wordIndex = 0
	bits.bitIndex = 0
	seekstart(bits.file)
	bits.tempWord = read(bits.file, UInt64)
end

function next(bits::StreamSource)
	res = bits.tempWord & 1
	if (bits.bitIndex < 63)
	    bits.bitIndex = bits.bitIndex + 1
	    bits.tempWord = bits.tempWord >> 1
	else
	    bits.wordIndex = bits.wordIndex + 1
	    bits.bitIndex = 0
	    bits.tempWord = read(bits.file, UInt64)
	end
	return res
end

function stop(bits::FileSource)
	close(bits.file)
end

function stop(bits::CmdSource)
	close(bits.file)
	rm(bits.tmpf)
end

end # Module

