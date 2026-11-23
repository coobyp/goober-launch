--!strict
-- Number formatting for UI: 1234 -> "1.23K", 5_600_000 -> "5.6M".

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local Format = {}

function Format.short(n: number): string
	local value = math.floor(n)
	if math.abs(value) < 1000 then
		return tostring(value)
	end
	local tier = 1
	local scaled = value
	while math.abs(scaled) >= 1000 and tier < #SUFFIXES do
		scaled /= 1000
		tier += 1
	end
	local text = if math.abs(scaled) >= 100
		then string.format("%d", math.floor(scaled))
		elseif math.abs(scaled) >= 10 then string.format("%.1f", math.floor(scaled * 10) / 10)
		else string.format("%.2f", math.floor(scaled * 100) / 100)
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text .. SUFFIXES[tier]
end

function Format.cash(n: number): string
	return "$" .. Format.short(n)
end

function Format.rate(n: number): string
	if n < 10 and n ~= math.floor(n) then
		return "$" .. string.format("%.1f", n) .. "/s"
	end
	return "$" .. Format.short(n) .. "/s"
end

function Format.studs(n: number): string
	return Format.short(n) .. " studs"
end

function Format.duration(seconds: number): string
	local s = math.floor(seconds)
	local h = s // 3600
	local m = (s % 3600) // 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	if m > 0 then
		return string.format("%dm %ds", m, s % 60)
	end
	return string.format("%ds", s)
end

return Format
