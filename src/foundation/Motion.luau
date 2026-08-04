local TweenService = game:GetService("TweenService")

local Motion = {}

Motion.curve = {
	state = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	enter = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	reveal = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	exit = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	hover = TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
	color = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	snap = TweenInfo.new(0.07, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
	slide = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

Motion.staggerStep = 0.02
Motion.staggerCap = 8
Motion.revealLift = 8

local active = setmetatable({}, { __mode = "k" })

function Motion.cancel(instance: Instance)
	local record = active[instance]
	if not record then
		return
	end
	for property, tween in record do
		pcall(function()
			tween:Cancel()
		end)
		record[property] = nil
	end
end

function Motion.set(instance: Instance, props: { [string]: any })
	if typeof(instance) ~= "Instance" then
		return
	end
	Motion.cancel(instance)
	for property, value in props do
		pcall(function()
			(instance :: any)[property] = value
		end)
	end
end

function Motion.tween(instance: Instance, curve: TweenInfo, props: { [string]: any }, trove): Tween?
	if typeof(instance) ~= "Instance" then
		return nil
	end

	local record = active[instance]
	if not record then
		record = {}
		active[instance] = record
	end

	for property in props do
		local existing = record[property]
		if existing then
			pcall(function()
				existing:Cancel()
			end)
		end
	end

	local ok, tween = pcall(TweenService.Create, TweenService, instance, curve, props)
	if not ok or typeof(tween) ~= "Instance" then
		return nil
	end

	for property in props do
		record[property] = tween
	end

	tween.Completed:Once(function()
		for property, stored in record do
			if stored == tween then
				record[property] = nil
			end
		end
		if trove then
			trove:Remove(tween)
		end
		pcall(function()
			tween:Destroy()
		end)
	end)

	if trove then
		trove:Add(tween)
	end

	tween:Play()
	return tween
end

function Motion.stagger(items: { Instance }, curve: TweenInfo, propsFor, step: number?, trove)
	local gap = step or Motion.staggerStep

	local capped = math.min(#items, Motion.staggerCap)

	for index, item in items do
		local wait = (math.min(index, capped) - 1) * gap

		if wait <= 0 then
			Motion.tween(item, curve, propsFor(item, index), trove)
		else
			local thread
			thread = task.delay(wait, function()
				if trove and thread then
					trove:Remove(thread)
				end
				if typeof(item) ~= "Instance" or item.Parent == nil then
					return
				end
				Motion.tween(item, curve, propsFor(item, index), trove)
			end)
			if trove then
				trove:Add(thread)
			end
		end
	end
end

function Motion.after(seconds: number, callback: () -> (), trove)
	local thread
	thread = task.delay(seconds, function()
		if trove and thread then
			trove:Remove(thread)
		end
		callback()
	end)

	if trove then
		trove:Add(thread)
	end

	return thread
end

return Motion
