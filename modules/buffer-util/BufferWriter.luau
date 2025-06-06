--!native

local MAX_SIZE = 1073741824

local DataTypeBuffer = require(script.Parent.DataTypeBuffer)
local Types = require(script.Parent.Types)

--[=[
	@class BufferWriter
	
	A BufferWriter is an abstraction wrapper for `buffer` objects
	that provides a convenient way of writing data to buffers.

	The internal buffer is automatically resized to fit the data
	that is being written.
]=]
local BufferWriter = {}
BufferWriter.__index = BufferWriter

function BufferWriter.new(initialSize: number?): Types.BufferWriter
	local size = if typeof(initialSize) == "number" then math.clamp(initialSize, 0, MAX_SIZE) else 0

	local self = setmetatable({
		_buffer = buffer.create(size),
		_cursor = 0,
		_size = 0,
	}, BufferWriter)

	return self
end

function BufferWriter:_resizeUpTo(desiredSize: number)
	if desiredSize > MAX_SIZE then
		error(`cannot resize buffer to {desiredSize} bytes (max size: {MAX_SIZE} bytes)`, 3)
	end

	self._size = math.max(self._size, desiredSize)

	if desiredSize < buffer.len(self._buffer) then
		return
	end

	local newSize = desiredSize

	local powerOfTwo = math.log(desiredSize, 2)
	if math.floor(powerOfTwo) ~= powerOfTwo then
		newSize = 2 ^ (math.floor(powerOfTwo) + 1)
	end

	local oldBuffer = self._buffer
	local newBuffer = buffer.create(newSize)

	buffer.copy(newBuffer, 0, oldBuffer, 0)

	self._buffer = newBuffer
end

--[=[
	Write a signed 8-bit integer to the buffer.
]=]
function BufferWriter:WriteInt8(int8: number)
	self:_resizeUpTo(self._cursor + 1)
	buffer.writei8(self._buffer, self._cursor, int8)
	self._cursor += 1
end

--[=[
	Write an unsigned 8-bit integer to the buffer.
]=]
function BufferWriter:WriteUInt8(uint8: number)
	self:_resizeUpTo(self._cursor + 1)
	buffer.writeu8(self._buffer, self._cursor, uint8)
	self._cursor += 1
end

--[=[
	Write a signed 16-bit integer to the buffer.
]=]
function BufferWriter:WriteInt16(int16: number)
	self:_resizeUpTo(self._cursor + 2)
	buffer.writei16(self._buffer, self._cursor, int16)
	self._cursor += 2
end

--[=[
	Write an unsigned 16-bit integer to the buffer.
]=]
function BufferWriter:WriteUInt16(uint16: number)
	self:_resizeUpTo(self._cursor + 2)
	buffer.writeu16(self._buffer, self._cursor, uint16)
	self._cursor += 2
end

--[=[
	Write a signed 32-bit integer to the buffer.
]=]
function BufferWriter:WriteInt32(int32: number)
	self:_resizeUpTo(self._cursor + 4)
	buffer.writei32(self._buffer, self._cursor, int32)
	self._cursor += 4
end

--[=[
	Write an unsigned 32-bit integer to the buffer.
]=]
function BufferWriter:WriteUInt32(uint32: number)
	self:_resizeUpTo(self._cursor + 4)
	buffer.writeu32(self._buffer, self._cursor, uint32)
	self._cursor += 4
end

--[=[
	Write a 32-bit single-precision float to the buffer.
]=]
function BufferWriter:WriteFloat32(f32: number)
	self:_resizeUpTo(self._cursor + 4)
	buffer.writef32(self._buffer, self._cursor, f32)
	self._cursor += 4
end

--[=[
	Write a 64-bit double-precision float to the buffer.
]=]
function BufferWriter:WriteFloat64(f64: number)
	self:_resizeUpTo(self._cursor + 8)
	buffer.writef64(self._buffer, self._cursor, f64)
	self._cursor += 8
end

--[=[
	Write a boolean to the buffer.
]=]
function BufferWriter:WriteBool(bool: boolean)
	self:WriteUInt8(if bool then 1 else 0)
end

--[=[
	Write a string to the buffer. An optional `length` argument can
	be provided to limit the number of bytes read from the string.

	:::info
	An extra 32-bit integer is stored before the string to mark the
	length of the string. If the length of the string is always
	known, it is more memory-efficient to use `WriteStringRaw`.
	:::
]=]
function BufferWriter:WriteString(str: string, length: number?)
	local len = if length then math.min(#str, length) else #str
	local size = len + 4
	self:_resizeUpTo(self._cursor + size)
	buffer.writeu32(self._buffer, self._cursor, len)
	buffer.writestring(self._buffer, self._cursor + 4, str, length)
	self._cursor += size
end

--[=[
	Write a string to the buffer. An optional `length` argument can
	be provided to limit the number of bytes read from the string.

	:::info
	The length of the string must be known to the reader in order to
	read this string from the buffer, as the length of the string is
	not stored in the buffer. For strings of dynamic/unknown length,
	use `WriteString` instead.
	:::
]=]
function BufferWriter:WriteStringRaw(str: string, length: number?)
	local len = if length then math.min(#str, length) else #str
	self:_resizeUpTo(self._cursor + len)
	buffer.writestring(self._buffer, self._cursor, str, length)
	self._cursor += len
end

--[=[
	Write a DataType to the buffer.

	```lua
	writer:WriteDataType(CFrame.new(0, 10, 5))
	```
]=]
function BufferWriter:WriteDataType(value: any)
	local t = typeof(value)
	local readWrite = DataTypeBuffer.ReadWrite[t]
	if not readWrite then
		error(`unsupported data type "{t}"`, 2)
	end
	readWrite.write(self, value)
end

--[=[
	Shrinks the capacity of the buffer to the current data size.
]=]
function BufferWriter:Shrink()
	if self._size == buffer.len(self._buffer) then
		return
	end

	local oldBuffer = self._buffer
	local newBuffer = buffer.create(self._size)

	buffer.copy(newBuffer, 0, oldBuffer, 0, self._size)

	self._buffer = newBuffer
end

--[=[
	Returns the current data size of the buffer. This is _not_ necessarily
	equal to the capacity of the buffer.
]=]
function BufferWriter:GetSize(): number
	return self._size
end

--[=[
	Returns the current capacity of the buffer. This is the length of the
	internal buffer, which is usually not the same as the length of the stored
	data.

	The buffer capacity automatically grows as data is added.
]=]
function BufferWriter:GetCapacity(): number
	return buffer.len(self._buffer)
end

--[=[
	Sets the position of the cursor.
]=]
function BufferWriter:SetCursor(position: number)
	position = math.floor(position)
	if position < 0 or position > self._size then
		error(`cursor position {position} out of range [0, {self._size}]`, 3)
	end

	self._cursor = position
end

--[=[
	Gets the position of the cursor.
]=]
function BufferWriter:GetCursor(): number
	return self._cursor
end

--[=[
	Resets the position of the cursor.
]=]
function BufferWriter:ResetCursor()
	self._cursor = 0
end

--[=[
	Returns the `buffer` object.
]=]
function BufferWriter:GetBuffer(): buffer
	return self._buffer
end

--[=[
	Returns the string version of the internal buffer.
]=]
function BufferWriter:ToString(): string
	return buffer.tostring(self._buffer)
end

function BufferWriter:__tostring()
	return "BufferWriter"
end

return BufferWriter
