--!strict

export type Result<T, E> = {
	__index: Result<T, E>,
	__tostring: (self: Result<T, E>) -> (string),
	_err: E?,
	_ok: T?,
	Err: (err: E) -> (Result<T, E>),
	Ok: (ok: T) -> (Result<T, E>),
	unwrap: (self: Result<T, E>) -> (T),
	unwrapOr: <R>(self: Result<T, E>, replacement: R) -> (T | R),
	mapErr: (self: Result<T, E>, err: any) -> ()
}

local Result = {} :: Result<any, any>
Result.__index = Result

function Result.__tostring(self)
	if self._ok then
		return `Result::Ok({self._ok})`
	end
	return `Result::Err({self._err})`
end

function Result.Err(err)
	return setmetatable({
		_err = err
	}, Result) :: any
end

function Result.Ok(ok)
	return setmetatable({
		_ok = ok
	}, Result) :: any
end

function Result.unwrap(self)
	if self._err then
		error(self._err)
	end
	return self._ok
end

function Result.unwrapOr(self, replacement)
	if self._err then
		return replacement
	end
	return self._ok
end

function Result.mapErr(self, err)
	if self._err then
		return err
	end
	return self._ok
end

return Result
