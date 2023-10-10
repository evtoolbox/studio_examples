local logger = set_lua_logger("Corousel")
local audio = reactorController:getReactorByName("Audio_click")
local image_insrt = reactorController:getReactorByName("Scroll")

Corousel = class("Corousel")
	:field("reactor")	-- must be rect

	:field("_startPos", nil)
	:field("_pushPos", nil)
	:field("_touchId", nil)

	:field("eventHandler")
	:field("isMultitouch")
:done()


function Corousel:_construct(reactor)
	self.reactor = reactor
	self.isMultitouch = false

	-- NOTE: All children must be rect with 100v width/height
	-- Horizontal mode only

	local elementsCount = #self.reactor.children	-- NOTE: must be non-zero
	if elementsCount < 1 then
		error("At least one element must be presented in corousel")
	end

	local containerWidth = self.reactor.rect.size.x.value/elementsCount
	local margin_x = (containerWidth - 100.0)/2

	if self.reactor.rect.size.x.value < elementsCount*100 then
		error("Carousel width must be >= " ..  tostring(elementsCount*100) .. "v")
	end

	-- TODO: autoposition flag
	-- logger:error("Margin = ", margin_x)
	do
		self.reactor:freeze()
		local pos = margin_x
		for i, page in ipairs(self.reactor.children) do
			-- logger:error(page.name)
			page.rect.shift = ScreenPosition(ScreenUnitLength(pos, "%v"), page.rect.shift.y)
			pos = pos + 100 + 2*margin_x
		end

		self.reactor.rect.shift = ScreenPosition(ScreenUnitLength(-margin_x, "%v"), self.reactor.rect.shift.y)
		self.reactor:thaw()
		self.reactor:configure()
	end

	local velocityArr = {}
	local function move(shift_x)
		self.reactor.node:setUpdateCallback(nil)

		local pos = self._startPos + osg.Vec3(shift_x, 0.0, 0.0)
		

		-- constraints
		local elementsCount = #self.reactor.children
		local x_min = -self.reactor.rect.sizeRaw.x*(elementsCount - 1)/elementsCount
		
		-- local x_prev = self.reactor.node:getPosition():x()
		local x_curr = pos:x()
		x_curr = math.min(math.max(x_min, x_curr), 0.0)
		pos:x(x_curr)

		local time = viewer:getFrameStamp():getSimulationTime()
		table.insert(velocityArr, { t = time, x = x_curr })			-- NOTE: can be used for integral

		self.reactor.node:setPosition(pos)
	end

	local function moveEnd()
		-- logger:error("move end!")
		local pos = self.reactor.node:getPosition()

		local x_start = pos:x()


		local x_finish = 0.0	-- TODO: nearest to
		local elementsCount = #self.reactor.children
		local elementWidth =  self.reactor.rect.sizeRaw.x/elementsCount
		

		local distance = elementWidth*(elementsCount + 1)

		local time = viewer:getFrameStamp():getSimulationTime()

		-- find nearest to 'time' and to 'time - 0.2' from
		local v1, v2 = { t = nil, x = nil }, { t = nil, x = nil }
		for _, v in pairs(velocityArr) do
			if not v1.t or math.abs(v.t - time) < math.abs(v.t - v1.t) then
				v1.t, v1.x = v.t, v.x
				
			end
			if not v2.t or math.abs(v.t - time - 0.2) < math.abs(v.t - v2.t) then
				v2.t, v2.x = v.t, v.x
			end
		end
		velocityArr = {}

		local moveVelocity = v1.t and v2.t and (v1.t - v2.t) > 0.0 and (v2.x - v1.x)/(v2.t - v1.t) or 0.0
		if moveVelocity == 0.0 then
			return
		end

		local vsign = moveVelocity < 0 and -1.0 or 1.0

		-- logger:error("v1.t = ", v1.t, "; v2.t = ", v2.t)

		-- NOTE: first margin + velocity approx
		local x_start_predicted = x_start + vsign*math.min(math.abs(moveVelocity*0.5), elementWidth/2)	-- TODO: configurable
		-- logger:error("el width = ", elementWidth, "; moveVelocity = ", moveVelocity, "start = ", x_start, "; predicted = ", x_start_predicted)
		local fSlide = 0
		for i = 0,  elementsCount - 1 do
			local d = math.abs(x_start_predicted + i*elementWidth)	-- margin!!!
			if d < distance then
				distance = d
				x_finish = -i*elementWidth
				fSlide = i;
				
			end
		end

		local startTime	= nil
		local period	= nil

		local stabilizationAnimationCallback = osg.NodeCallback(function()
			local time = viewer:getFrameStamp():getSimulationTime()
 
			if not startTime then
				startTime = time
				period = math.max(0.25*math.abs(x_finish - x_start), 0.1)	-- TODO: coeff
				--logger:error("PERIOD = ", period)
			end

			local elapsed = time - startTime

			if elapsed > period then
				elapsed = period
				self.reactor.node:setUpdateCallback(nil)
				
				
				local resName= "circle_new" .. tostring(fSlide+ 1) .. ".png"
				logger:error(resName)
				local res = resourceRepository:getResourceByName(resName)
				logger:error(tostring(res))

				local reactor = reactorController:getReactorByName("Scroll")
				if res then
					reactor.image.resourceId = res.id
				end

			end

			local k1 = elapsed/period
--			k1 = k1*k1
--			k1 = k1*k1*(1.5 - k1)*2.0
			k1 = 0.5 + math.sin((k1 - 0.5)*math.pi)/2
			local k2 = 1.0 - k1
			local x = x_finish*k1 + x_start*k2

			local p = self.reactor.node:getPosition()
			p:x(x)
			self.reactor.node:setPosition(p)
			

			return true
		end)

		self.reactor.node:setUpdateCallback(stabilizationAnimationCallback)
		audio:play()
	end

	self.eventHandler = osgGA.GUIEventHandler(function(ea)
		local eventType = ea:getEventType()

		if eventType == osgGA.GUIEventAdapter.FRAME then
			return false	-- skip frame event
		end

		-- TODO: RESIZE

		if ea:isMultiTouchEvent() then
			-- Multitouch

			self.isMultitouch = true	-- NOTE: Suppose that one time multitouch => multitouch!

			local function getTouchPosition(tp)
				local x, y = tp:getX(), tp:getY()
				local wh = ea:getWindowHeight()
				local aspect = ea:getWindowWidth()/wh
				local position = osg.Vec2(x/wh - 0.5*aspect, y/wh - 0.5)

				-- logger:error("x = ", position:x(), "; y = ", position:y())

				return position
			end

			local touchData = ea:getTouchData()

			local activeTouchFound = false
			for i = 0, touchData:getNumTouchPoints() - 1 do
				local tp	= touchData:get(i)
				local phase	= tp:getTouchPhase()
				local id	= tp:getId()
				

				if not self._touchId and phase == osgGA.GUIEventAdapter.TOUCH_BEGAN then
					-- Interaction begin
					logger:debug("Interaction begin")

					activeTouchFound	= true
					self._touchId		= id
					self._pushPos		= getTouchPosition(tp)
					self._startPos		= self.reactor.node:getPosition()
					
					
				
				end

				-- logger:error("id = ", id, "; active = ", self._touchId)

				if id == self._touchId then
					-- Interaction
					logger:debug("Interaction")

					local currentPos = getTouchPosition(tp)
					local shift_x = currentPos:x() - self._pushPos:x()
					move(shift_x)
					
					if phase ~= osgGA.GUIEventAdapter.TOUCH_ENDED then
						activeTouchFound = true
						audio:play()
					end 

					break
				end
			end

			if self._touchId and not activeTouchFound then
				logger:debug("Interaction end", touchData:getNumTouchPoints(), self._touchId, activeTouchFound)

				-- End of interaction
				self._touchId	= nil
				self._startPos	= nil
				moveEnd()
			
			end

		elseif not self.isMultitouch then
			-- Mouse

			local function getCursorPosition()
				local w = ea:getWindowWidth()
				local h = ea:getWindowHeight()
				local x = ea:getXnormalized()*w/(2*h)	-- 1.0 is height (0.0 in the center)
				local y = ea:getYnormalized()/2			-- 1.0 is height (0.0 in the center)

				return osg.Vec2(x, y)
			end

			local mouseButtonId = osgGA.GUIEventAdapter.LEFT_MOUSE_BUTTON

			local buttonsMask = ea:getButtonMask()
			-- if bit_and(buttonsMask, mouseButtonId) == 0 then
			-- 	-- logger:error("need left button")
			-- 	return false
			-- end

			if eventType == osgGA.GUIEventAdapter.PUSH then
				self._pushPos = getCursorPosition()
				self._startPos = self.reactor.node:getPosition()
				move(0.0)	-- stoppn
				
			elseif eventType == osgGA.GUIEventAdapter.RELEASE then
				self._pushPos	= nil
				self._startPos	= nil
				moveEnd()
			
			end


			if eventType == osgGA.GUIEventAdapter.DRAG or eventType == osgGA.GUIEventAdapter.MOVE then
				if self._pushPos then
					local currentPos = getCursorPosition()
					local shift_x = currentPos:x() - self._pushPos:x()
					move(shift_x)
				end
			end
		end


		return false
	end)
end


function Corousel:init()
	local p = self.reactor.node:getPosition()
	self.reactor.node:setUpdateCallback(nil)
	p:x(0)
	self.reactor.node:setPosition(p)
end

function Corousel:enable()
	viewer:addEventHandler(self.eventHandler)
end

function Corousel:disable()
	viewer:removeEventHandler(self.eventHandler)
end
