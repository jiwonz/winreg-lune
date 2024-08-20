local function smallest_multiple(a, b)
    -- Find the smallest multiple of `b` that is >= `a`
    local result
    if a % b == 0 then
        -- If `a` is already a multiple of `b`, return `a`
        result = a
    else
        -- Find the smallest multiple of `b` greater than `a`
        result = math.ceil(a / b) * b
    end
    return result
end

-- Example usage:
print(smallest_multiple(6, 8)) -- Output: 8
print(smallest_multiple(12, 8)-12) -- Output: 16
